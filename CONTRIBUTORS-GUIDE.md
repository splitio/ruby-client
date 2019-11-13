# Contributing to the Split Ruby SDK
 
Split SDK is an open source project and we welcome feedback and contribution. The information below describes how to build the project with your changes, run the tests, and send the Pull Request(PR).
 
## Development

### Development process
 
1. Fork the repository and create a topic branch from `development` branch. Please use a descriptive name for your branch.
2. While developing, use descriptive messages in your commits. Avoid short or meaningless sentences like "fix bug".
3. Make sure to add tests for both positive and negative cases.
4. Run the linter script of the project and fix any issues you find.
5. Run the build script and make sure it runs with no errors.
6. Run all tests and make sure there are no failures.
7. `git push` your changes to GitHub within your topic branch.
8. Open a Pull Request(PR) from your forked repo and into the `development` branch of the original repository.
9. When creating your PR, please fill out all the fields of the PR template, as applicable, for the project.
10. Check for conflicts once the pull request is created to make sure your PR can be merged cleanly into `development`.
11. Keep an eye out for any feedback or comments from Split's SDK team.

### Building the SDK
To install this gem dependencies onto your local machine, run `bundle exec rake install`.

Then you can build the gem using `gem build splitclient-rb.gemspec` and install on your Ruby version with `gem install splitclient-rb-X.X.X.gem` (_the version number should match what you just built_).

### Running tests
The gem uses `rspec` for unit testing. You can find the files for the unit tests and the specs helper file (`spec_helper.rb`) under the default `/spec` folder.

To run all the specs in the `spec` folder, use the provided rake task (_make sure Redis is running in localhost_):

```bash
  bundle exec rspec
```

`Simplecov` is used for coverage reporting. Upon executing the rake task it will store the reports in the `/coverage` folder.

### Linting and other useful checks
To run the static code analysis using Rubocop run:
```bash
bundle exec rubocop
```

If you want to benchmark the hashing algorithm (MurmurHash) run:
```bash
bundle exec rake compile:murmurhash
```
 
# Contact
If you have any other questions or need to contact us directly in a private manner send us a note at developers@split.io