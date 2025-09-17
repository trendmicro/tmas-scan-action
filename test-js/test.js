// Copyright (C) 2025 Trend Micro Inc. All rights reserved.

const assert = require('assert');
const fs = require('fs');

const script = require('../tmas-scripts/notify_github.js');
const { getMockCore, getMockContext, getMockGithubClient, assertMockCalls } = require('./mocks.js');


const exampleOwner = "test-owner";
const exampleRepo = "test-repo";
const exampleBranch = "test-branch";
const examplePushRef = `refs/heads/${exampleBranch}`;
const examplePRRef = `refs/pull/47/merge`;
const examplePRHeadRef = exampleBranch;
const exampleWorkflow = "Scan artifact";
const pushEvent = "push";
const prEvent = "pull_request";
const workflowDispatchEvent = "workflow_dispatch";

(async () => {
  await Test_NotifyGithub();
  await Test_NotifyGithub_Triggers();
  await Test_NotifyGithub_Errors();
})();

async function Test_NotifyGithub() {
    const mockCore = getMockCore();
    const mockContext = getMockContext({
      repoOwner: exampleOwner,
      repoName: exampleRepo,
      ref: examplePushRef,
      workflow: exampleWorkflow,
      eventName: pushEvent
    });
    const defaultInputs = {
      artifact: "container:latest",
      markdownFile: "test-js/test-data/markdownReport.md",
      vulnerabilitiesScan: "true",
      malwareScan: "true",
      secretsScan: "true"
    }

  // Load the example markdown content
  const exampleComment = fs.readFileSync("test-js/test-data/expectedGithubComment.md", 'utf-8');

  const testCases = [
    {
      name: "TMAS did not complete successfully, no markdown file available, exit gracefully",
      mockResponses: {},
      expectedCalls: {},
      inputs: {...defaultInputs, ...{ markdownFile: "nonExistentFile.md" } }
    },
    {
      name: "PR found linked to branch, new comment made",
      mockResponses: {
        listPulls: {
          data: [
            { number: 5 }
          ]
        },
        listComments: {
          data: [
            { id: 1, body: "User comment" }
          ]
        }
      },
      expectedCalls: {
        listPulls: [
          { owner: exampleOwner, repo: exampleRepo, head: `${exampleOwner}:${exampleBranch}` }
        ],
        listComments: [
          { owner: exampleOwner, repo: exampleRepo, issue_number: 5, page: 1 }
        ],
        createComment: [
          { issue_number: 5, owner: exampleOwner, repo: exampleRepo, body: exampleComment }
        ]
      },
      inputs: defaultInputs
    },
    {
      name: "PR found linked to branch, existing comment updated",
      mockResponses: {
        listPulls: {
          data: [
            { number: 5 }
          ]
        },
        listComments: {
          data: [
            { id: 1, body: exampleComment }
          ]
        },
      },
      expectedCalls: {
        listPulls: [
          { owner: exampleOwner, repo: exampleRepo, head: `${exampleOwner}:${exampleBranch}` }
        ],
        listComments: [
          { owner: exampleOwner, repo: exampleRepo, issue_number: 5, page: 1 }
        ],
        updateComment: [
          { comment_id: 1, owner: exampleOwner, repo: exampleRepo, body: exampleComment }
        ]
      },
      inputs: defaultInputs
    },
    {
      name: "No PR found linked to branch, graceful exit",
      mockResponses: {
        listPulls: {
          data: []
        }
      },
      expectedCalls: {
        listPulls: [
          { owner: exampleOwner, repo: exampleRepo, head: `${exampleOwner}:${exampleBranch}` }
        ]
      },
      inputs: defaultInputs
    },
    {
      name: "Multiple PRs found linked to branch, multiple comments made",
      mockResponses: {
        listPulls: {
          data: [
            { number: 5 },
            { number: 6 }
          ]
        },
        listComments: {
          data: [
            { id: 1, body: "User comment" },
            { id: 2, body: "User comment" }
          ]
        }
      },
      expectedCalls: {
        listPulls: [
          { owner: exampleOwner, repo: exampleRepo, head: `${exampleOwner}:${exampleBranch}` }
        ],
        listComments: [
          { owner: exampleOwner, repo: exampleRepo, issue_number: 5, page: 1 },
          { owner: exampleOwner, repo: exampleRepo, issue_number: 6, page: 1 }
        ],
        createComment: [
          { owner: exampleOwner, repo: exampleRepo, issue_number: 5, body: exampleComment },
          { owner: exampleOwner, repo: exampleRepo, issue_number: 6, body: exampleComment }
        ]
      },
      inputs: defaultInputs
    }
  ]

  for (const tc of testCases) {
    console.log(`\n** TEST ** Test_NotifyGithub: ${tc.name}`);

    const callRegistrations = {};
    const mockGithub = getMockGithubClient(tc.mockResponses, callRegistrations);

    await assert.doesNotReject(script({github: mockGithub, context: mockContext, core: mockCore, fs, inputs: tc.inputs}));

    assertMockCalls(tc.expectedCalls, callRegistrations)
    console.log(`PASSED: ${tc.name}`);
  }
}

async function Test_NotifyGithub_Triggers() {
  const mockCore = getMockCore();
  const inputs = {
    artifact: "container:latest",
    markdownFile: "test-js/test-data/markdownReport.md",
    vulnerabilitiesScan: "true",
    malwareScan: "true",
    secretsScan: "true"
  }

  const defaultMockResponses = {
    listPulls: {
      data: [
        { number: 5 }
      ]
    },
    listComments: {
      data: []
    }
  };

  const defaultExpectedCalls = {
    listPulls: [
      { owner: exampleOwner, repo: exampleRepo, head: `${exampleOwner}:${examplePRHeadRef}` }
    ],
    listComments: [
      { owner: exampleOwner, repo: exampleRepo, issue_number: 5, page: 1 }
    ],
    createComment: [
      { issue_number: 5, owner: exampleOwner, repo: exampleRepo, body: fs.readFileSync("test-js/test-data/expectedGithubComment.md", 'utf-8') }
    ]
  };


  const testCases = [
    {
      name: "Push event on branch, PR found linked to branch, new comment made",
      mockContext: getMockContext({
        repoOwner: exampleOwner,
        repoName: exampleRepo,
        ref: examplePushRef,
        workflow: exampleWorkflow,
        eventName: pushEvent
      }),
      mockResponses: defaultMockResponses,
      expectedCalls: defaultExpectedCalls
    },
    {
      name: "Pull request event, PR found linked to branch, new comment made",
      mockContext: getMockContext({
        repoOwner: exampleOwner,
        repoName: exampleRepo,
        ref: examplePRRef,
        workflow: exampleWorkflow,
        eventName: prEvent,
        payload: { pull_request: { head: { ref: examplePRHeadRef } } }
      }),
      mockResponses: defaultMockResponses,
      expectedCalls: defaultExpectedCalls
    },
    {
      name: "Workflow dispatch event on branch, PR found linked to branch, new comment made",
      mockContext: getMockContext({
        repoOwner: exampleOwner,
        repoName: exampleRepo,
        ref: examplePushRef,
        workflow: exampleWorkflow,
        eventName: workflowDispatchEvent
      }),
      mockResponses: defaultMockResponses,
      expectedCalls: defaultExpectedCalls
    },
    {
      name: "Unsupported event, graceful exit",
      mockContext: getMockContext({
        repoOwner: exampleOwner,
        repoName: exampleRepo,
        ref: examplePushRef,
        workflow: exampleWorkflow,
        eventName: "issue_comment"
      }),
      mockResponses: {},
      expectedCalls: {}
    }
  ]

  for (const tc of testCases) {
    console.log(`\n** TEST ** Test_NotifyGithub_Triggers: ${tc.name}`);

    const callRegistrations = {};
    const mockGithub = getMockGithubClient(tc.mockResponses, callRegistrations);

    await assert.doesNotReject(script({github: mockGithub, context: tc.mockContext, core: mockCore, fs, inputs}));

    assertMockCalls(tc.expectedCalls, callRegistrations)
    console.log(`PASSED: ${tc.name}`);
  }
}

async function Test_NotifyGithub_Errors() {
  const mockCore = getMockCore();
  const mockContext = getMockContext({
    repoOwner: exampleOwner,
    repoName: exampleRepo,
    ref: examplePushRef,
    eventName: pushEvent,
    workflow: exampleWorkflow
  });
  const inputs = {
    artifact: "container:latest",
    markdownFile: "test-js/test-data/markdownReport.md",
    vulnerabilitiesScan: "true",
    malwareScan: "true",
    secretsScan: "true"
  };

  // Load the example markdown content
  const markdownContent = fs.readFileSync(inputs.markdownFile, 'utf-8');
  const exampleComment = `# TMAS Scan Report\nScan Results for artifact \`container:latest\`\n${markdownContent}`;

  const testCases = [
    {
      name: "Fails the script when listPulls API returns 401",
      mockResponses: {
        listPulls: {
          error: {
            status: 401,
            message: "Unauthorized",
            name: "HttpError"
          }
        }
      },
      errorMessage: "Failed to query pull requests"
    },
    {
      name: "Fails the script when listComments API returns an error",
      mockResponses: {
        listPulls: {
          data: [
            { number: 5 }
          ]
        },
        listComments: {
          error: {
            status: 500,
            message: "Internal Server Error",
            name: "HttpError"
          }
        }
      },
      errorMessage: "Failed to query existing comments on PR #5"
    },
    {
      name: "Fails the script when creating a comment returns an error",
      mockResponses: {
        listPulls: {
          data: [
            { number: 5 }
          ]
        },
        listComments: {
          data: []
        },
        createComment: {
          error: {
            status: 403,
            message: "Forbidden",
            name: "HttpError"
          }
        }
      },
      errorMessage: "Failed to create comment on PR #5"
    },
    {
      name: "Fails the script when updating a comment returns an error",
      mockResponses: {
        listPulls: {
          data: [
            { number: 5 }
          ]
        },
        listComments: {
          data: [
            { id: 1, body: exampleComment }
          ]
        },
        updateComment: {
          error: {
            status: 404,
            message: "Not Found",
            name: "HttpError"
          }
        }
      },
      errorMessage: "Failed to update comment on PR #5"
    }
  ]

  for (const tc of testCases) {
    console.log(`\n** TEST ** Test_NotifyGithub_Errors: ${tc.name}`);

    const mockGithub = getMockGithubClient(tc.mockResponses, {});
    const expectedError = new Error(tc.errorMessage);

    scriptErrored = false;
    await assert.rejects(script({github: mockGithub, context: mockContext, core: mockCore, fs, inputs}), expectedError);

    console.log(`PASSED: ${tc.name}`);
  }
}