# How to Contribute

## Report an Issue
In case you find a bug or have a feature request, please feel free to file an issue here on GitHub. If the issue already exists, you can also up-vote it. When creating a new issue, you can set labels for easier categorization like `bug`, `enhancement` etc. Priority labels are usually set by the project leads.

## Extend Mita
There are two ways you can extend Mita:

1. _Provide or extend a Mita platform_: to run Mita on a particular device, we need a `platform` which describes this device. For details of how to build such a platform, check out _platform integrator guide_ (TBD).
2. _Extend the core language itself_: Mita is a programming language in its infancy. If you want to help build it, please find and file bug reports, or better yet provide a PR to fix it.

## Set up your Developer Workspace
1. Download the <a href="https://wiki.eclipse.org/Eclipse_Oomph_Installer" target="_blank">Eclipse Installer</a> and start it
3. On the first page, expand the menu on the upper right corner and select *Advanced Mode*
4. On the *Product* page, select *Eclipse IDE for Eclipse Comitters* and click *Next*
5. Add the Mita repository via the green "+" symbol. As catalog select *Github Projects* and as *Resource URIs* paste the following link: https://raw.githubusercontent.com/eclipse/mita/master/mita.setup
6. Select the new *Mita* project, which will appear in *Github Projects* -> *<User>* -> *Mita* and continue by clicking *Next*.
7. Choose a target folder for the installation by setting a *Root install folder* and an *Installation folder name* and click *Next*.
8. The setup is done. Click on *Finish* and the installation will be executed.
9. After this, a new Eclipse will be started. With the initial execution some *Setup Tasks* need to be executed. You can see the progress by clicking on the double arrow symbol on the bottom right. After finishing the *Setup Tasks* your environment is ready to use and should contain no errors.

## Write and Run Tests
Fixing a bug or introducing a new feature usually comes with writing a unit test to ensure that the new functionality will be still working in future. There are currently two test suites, one for testing code generators, and one for language specific tests:
* Code Generator Tests: org.eclipse.mita.program.generator.tests.AllTests
* Language (Xpect) Tests: org.eclipse.mita.program.tests.AllTests

Both test suites can be run from within your Eclipse workspace via `right-click -> Run As -> JUnit Plugin Tests`

## Create Pull Requests
In order to create a pull request you need a GitHub account as well as an Eclipse account.
1. Create your own fork of this repository.
2. Switch your git remote origin to reference your fork. You can do this directly in Eclipse: In the properties of the git repository just change the value of remote origin url.
3. Create a branch for the issue you want to work on. The branch name starts with the issue number followed by some descriptive words.
4. [Sign off](https://git-scm.com/docs/git-commit#git-commit--s) your commits using the same email address you are using for your Eclipse account. Please make sure you have signed the [Eclipse Contributor Agreement](https://www.eclipse.org/legal/ECA.php) in your Eclipse account. Otherwise your pull requests won't pass IP validation and we cannot merge them.
5. Push the branch into your fork repository.
6. Create a pull request here on GitHub by selecting your branch.
