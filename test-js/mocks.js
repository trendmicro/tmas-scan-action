// Copyright (C) 2025 Trend Micro Inc. All rights reserved.

const assert = require('assert');

function getMockCore() {
  return {
    info: function(message) {
      console.log(`INFO: ${message}`);
    },
    error: function(message) {
      console.log(`ERROR: ${message}`);
    },
    warning: function(message) {
      console.log(`WARNING: ${message}`);
    }
  };
}

function getMockContext(mockResponses) {
  return {
    repo: {
      owner: mockResponses.repoOwner,
      repo: mockResponses.repoName
    },
    ref: mockResponses.ref,
    workflow: mockResponses.workflow,
    eventName: mockResponses.eventName,
    payload: mockResponses.payload,
  };
}

// Function which returns a mock github object based on the mock responses given
// Api calls are registered for later validation
function getMockGithubClient(mockResponses, callRegistration) {
  return {
    rest: {
      pulls: {
        list: function({ owner, repo, head }) {
          console.log(`MOCK: Call to list pulls, with owner: ${owner}, repo: ${repo}, head: ${head}`);
          registerCall(callRegistration, "listPulls", { owner, repo, head });
          if (mockResponses?.listPulls?.error) {
            return Promise.reject(mockResponses.listPulls.error);
          }
          return Promise.resolve({
            data: mockResponses?.listPulls?.data
          });
        }
      },
      issues: {
        listComments: function({ owner, repo, issue_number, page }) {
          console.log(`MOCK: Call to list comments, with owner: ${owner}, repo: ${repo}, issue_number: ${issue_number}, page: ${page}`);
          registerCall(callRegistration, "listComments", { owner, repo, issue_number, page });
          if (mockResponses?.listComments?.error) {
            return Promise.reject(mockResponses.listComments.error);
          }
          if (page === 1) {
            return Promise.resolve({
              data: mockResponses?.listComments?.data
            });
          } else {
            return Promise.resolve({ data: [] });
          }
        },
        createComment: function({ issue_number, owner, repo, body }) {
          console.log(`MOCK: Call to create comment, with issue_number: ${issue_number}, owner: ${owner}, repo: ${repo}`);
          registerCall(callRegistration, "createComment", { issue_number, owner, repo, body });
          if (mockResponses?.createComment?.error) {
            return Promise.reject(mockResponses.createComment.error);
          }
          return Promise.resolve({ id: 2, body });
        },
        updateComment: function({ comment_id, owner, repo, body }) {
          console.log(`MOCK: Call to update comment, with comment_id: ${comment_id}, owner: ${owner}, repo: ${repo}`);
          registerCall(callRegistration, "updateComment", { comment_id, owner, repo, body });
          if (mockResponses?.updateComment?.error) {
            return Promise.reject(mockResponses.updateComment.error);
          }
          return Promise.resolve({ id: comment_id, body });
        }
      }
    },
    paginate: function(method, params) {
      params.page = 1;
      return method(params).then(res => res.data);
    }
  };
}

function registerCall(callRegistration, type, params) {
  if (!callRegistration[type]) {
    callRegistration[type] = [];
  }
  callRegistration[type].push(params);
}

function assertMockCalls(expectedCalls, actualCalls) {
  for (const [key, expected] of Object.entries(expectedCalls)) {
    const actual = actualCalls[key] || [];
    assert.deepEqual(
      actual,
      expected,
      `Unexpected calls for ${key}`
    );
  }
}

module.exports = {
  getMockCore,
  getMockContext,
  getMockGithubClient,
  assertMockCalls
};
