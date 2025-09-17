#!/usr/bin/env node
// Copyright (C) 2025 Trend Micro Inc. All rights reserved.
const commentLogo = "<img height=\"26px\" src=\"https://cli.artifactscan.cloudone.trendmicro.com/images/tm-logo.svg\">";
const commentTitle = "TMAS Scan Report";
const unauthorizedError = "Unable to access repo resources and write comments, please check that the GitHub token provided in the TMAS action call has the necessary permissions.";
const failureInstruction = "TMAS Scan results available in the github action logs only.";
const requestTimeout = 10000; // 10 seconds

// Use Github API to determine if this branch has an open pull request and find the pull request number
async function findPullRequest({github, context, core}) {
  // get branch name when action triggered from pull_request event
  var head = "";
  switch (context.eventName) {
    case 'pull_request':
      head = `${context.repo.owner}:${context.payload.pull_request.head.ref}`;
      break;
    case 'push':
      head = `${context.repo.owner}:${context.ref.replace('refs/heads/', '')}`;
      break;
    case 'workflow_dispatch':
      head = `${context.repo.owner}:${context.ref.replace('refs/heads/', '')}`;
      break;
    default:
      return [];
  }

  const pullRequests = await github.rest.pulls.list({
    owner: context.repo.owner,
    repo: context.repo.repo,
    head: head,
    request: {
      timeout: requestTimeout,
    },
  }).catch((error) => {
    throw new Error('Failed to query pull requests', {cause: error});
  });

  // Create a list of PR IDs
  return pullRequests.data.map(pr => pr.number);
}

// Use Github API to find if a previous comment on the PR exists
async function findPreviousComment({github, context, core, inputs, prNumber}) {
  // Determine substrings of matching comment
  const substringMatches = [
    commentTitle,
    `artifact \`${inputs.artifact}\``
  ];
  const substringNotMatches = [];
  // add all scanner substrings
  if (inputs.vulnerabilitiesScan == "true") {
    substringMatches.push("Vulnerabilities");
  } else {
    substringNotMatches.push("Vulnerabilities");
  }
  if (inputs.malwareScan == "true") {
    substringMatches.push("Malware");
  } else {
    substringNotMatches.push("Malware");
  }
  if (inputs.secretsScan == "true") {
    substringMatches.push("Secrets");
  } else {
    substringNotMatches.push("Secrets");
  }

  const comments = await github.paginate(github.rest.issues.listComments, {
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: prNumber,
    per_page: 100,
    request: {
      timeout: requestTimeout,
    },
  }).catch((error) => {
    throw new Error(`Failed to query existing comments on PR #${prNumber}`, {cause: error});
  });

  let matchingComment = null;
  matchingComment = comments.find(comment => {
    return substringMatches.every(substring => comment.body.includes(substring)) && substringNotMatches.every(substring => !comment.body.includes(substring));
  });

  if (matchingComment) {
    core.info(`Found previous comment: ${matchingComment.id}`);
  } else {
    core.info(`No previous comment found`);
  }
  return matchingComment
}

// Use Github API to create or update a comment on the PR
async function upsertComment({github, context, core, fs, inputs, prNumber, existingComment, commentContent}) {
  // Read the content of markdown file for comment content
  const commentHeader = `# ${commentLogo} ${commentTitle}\nScan Results for artifact \`${inputs.artifact}\`\n`;
  var commentBody = `${commentHeader}${commentContent}`;

  // When truncating finding tables, the markdown output contains the notification "Limited to 10 findings, the full list can be found in JSON output"
  // Replace comment substring "JSON output" with "the <Job> action logs" for more clarity in the GHA comment
  const workflowName = context.workflow ? context.workflow : "";
  const jobID = context.job ? context.job : "";
  const logLocation = jobID === "" ? `"${workflowName}"` : `"${workflowName} / ${jobID}"`;
  commentBody = commentBody.replace(/JSON output/, `the ${logLocation} action logs`);

  // If comment ID is empty, use GitHub API to create a comment on the PR, else update the existing comment
  if (!existingComment) {
    core.info(`Creating new comment`);
    await github.rest.issues.createComment({
      issue_number: prNumber,
      owner: context.repo.owner,
      repo: context.repo.repo,
      body: commentBody,
      request: {
        timeout: requestTimeout,
      },
    }).catch((error) => {
      throw new Error(`Failed to create comment on PR #${prNumber}`, {cause: error});
    });
  } else {
    core.info(`Updating existing comment: ${existingComment.id}`);
    await github.rest.issues.updateComment({
      comment_id: existingComment.id,
      owner: context.repo.owner,
      repo: context.repo.repo,
      body: commentBody,
      request: {
        timeout: requestTimeout,
      },
    }).catch((error) => {
      throw new Error(`Failed to update comment on PR #${prNumber}`, {cause: error});
    });
  }
}

module.exports = async ({ github, context, core, fs, inputs}) => {
  const commentContent = await fs.promises.readFile(inputs.markdownFile, 'utf8').catch((error) => {
    if (error.code === 'ENOENT') {
      core.warning("No results available, please check that the TMAS scan completed successfully");
    } else {
      core.warning(failureInstruction);
      throw error;
    }
  });
  if (!commentContent) {
    return;
  }

  let prIds = [];
    prIds = await findPullRequest({github, context, core}).catch((error) => {
      if (error.cause?.status && (error.cause.status === 401 || error.cause.status === 403 || error.cause.status === 404)) {
        core.error(unauthorizedError);
      }
      core.warning(failureInstruction);
      throw error;
    });

    if (prIds && prIds.length > 0) {
      core.info(`Found open pull request(s): ${prIds.join(', ')}`);
    } else {
      core.info(`No open pull request found for branch: ${context.ref}. TMAS scan results available in the github action logs`);
      return;
    }

  for (const prId of prIds) {
    try {
      const existingComment = await findPreviousComment({github, context, core, inputs, prNumber: prId});
      await upsertComment({github, context, core, fs, inputs, prNumber: prId, existingComment, commentContent})
    } catch (error) {
      if (error.cause?.status && (error.cause.status === "401" || error.cause.status === "403" || error.cause.status === "404")) {
        core.error(unauthorizedError);
      }
      core.warning(failureInstruction);
      throw error;
    }
  }
}
