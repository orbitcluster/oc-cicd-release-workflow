module.exports = {
  branches: ["main"],
  plugins: [
    ["@semantic-release/commit-analyzer",
    {
      preset: 'conventionalcommits',
      releaseRules: [
        {breaking: true, release: 'major'},
        {type: 'perf', release: 'patch'},
        {type: 'fix', release: 'patch'},
        {type: 'chore', release: 'patch'},
        {type: 'feat', release: 'minor'},
        {type: 'refactor', release: 'patch'},
        {type: 'revert', release: 'patch'},
      ],
    }
  ],
  [
    "@semantic-release/release-notes-generator",
    {
      preset: 'conventionalcommits',
      presetConfig: {
        types: [
          {type: 'feat', section: 'Features'},
          {type: 'fix', section: 'Bug Fixes'},
          {type: 'perf', section: 'Performance Improvements'},
          {type: 'chore', section: 'Chores'},
          {type: 'refactor', section: 'Code Refactoring'},
          {type: 'revert', section: 'Reverts'},
          {type: 'style', section: 'Style'},
          {type: 'test', section: 'Tests'},
          {type: 'docs', section: 'Documentation'},
          {type: 'ci', section: 'CI/CD'},
          {type: 'build', section: 'Build'},
        ],
      }
    }
  ],
  [
    "@semantic-release/exec",
    {
      analyzeCommitsCmd: "echo \"${lastRelease.version}\" > LAST_VERSION.txt",
      verifyReleaseCmd: "echo \"${nextRelease.version}\" > VERSION.txt"
    }
  ],
  [
    "semantic-release-major-tag",
    {
      "customTags": process.env['TAG_COMPONENTS'] && ['v${major}', 'v${major}.${minor}'] || []
    }
  ],
  [
    "@semantic-release/github",
    {
     "successCommentCondition" : false,
     "failCommentCondition" : false,
    }
  ]
]
}
