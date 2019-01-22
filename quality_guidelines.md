# Quality Guidelines

This page describes which criteria commits, pull requests and code have to fulfill to find their way into the code base.

## Commits

### Message
Commit messages describe what you did and why. They consist of a subject line which should not exceed 50 characters and an optional body for a more detailed description. 
Read this [guide](https://chris.beams.io/posts/git-commit/) to understand why good commit messages matter and how they look like. 

As a summary, you should keep the following rules in mind:
1. Limit the subject line to 50 characters
2. Use the body to explain *what* and *why* vs. *how*
3. Separate subject from body with a blank line
4. Use the imperative mood in the subject line

### Contents
1. Commits should not mix unrelated changes.
2. Squash commits if they belong to the same logical change.
3. Do not mix formatting of existing code with actual contribution.
4. Usually, do not commit generated code.
5. Do not commit user-sepcific settings containing location on you local machine.

## Pull Requests

1. A pull request contains all commits required to implement one issue. Do not mix multiple issues in one pull request.
2. A pull request usually contains one or more test cases related to the issue.
3. Make sure your pull request is not too large. If it gets too large, think about splitting it. One way is to separate refactoring code into a first PR and put your actual semantic changes into a second PR.

## Code

Here are some basic guidelines for writing readable, understandable code:
1. Split your code semantically into classes and methods according to the [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle).
2. Give your classes, methods and variables meaningful names.
3. Use comments only if you need to explain something that is not clear from your code. Before you put comments, think about rewriting your code to make it better understandable.
4. Use the standard Eclipse formatter (Ctrl+F) before committing.
5. Remove warnings from your code (unused variables, imports etc.) before committing.
6. Prefer using [Xtend](https://www.eclipse.org/xtend/) over Java. In most cases it is more concise and improves readability.
7. Use [Google Guice](https://github.com/google/guice/wiki/Motivation) for dependency injection instead of instantiating objects manually.
