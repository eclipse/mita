## How to contribute

### Report an issue
In case you find a bug or have a feature request, please feel free to file an issue here on GitHub. If the issue already exists, you can also up-vote it. When creating a new issue, you can set labels for easier categorization like `bug`, `enhancement` etc. Priority labels are usually set by the project leads.

### Extending Mita
There are two ways you can extend Mita:

1. _Provide or extend a Mita platform_: to run Mita on a particular device, we need a `platform` which describes this device. For details of how to build such a platform, check out _platform integrator guide_ (TBD).
2. _Extend the core language itself_: Mita is a programming language in its infancy. If you want to help build it, please find and file bug reports, or better yet provide a PR to fix it.

### Setting up developer workspace
1. Download the <a href="https://wiki.eclipse.org/Eclipse_Oomph_Installer" target="_blank">Oomph Eclipse Installer</a>
2. Execute the installer
3. Expand the menu on the upper right corner and select *Advanced Mode*
4. Select *Eclipse IDE for Eclipse Comitters* on the *Product* page and click on *Next*
5. Add the Mita Repository via the green "+" symbol. As catalog select *Github Projects* and as *Resource URIs* paste the following link: https://raw.githubusercontent.com/eclipse/mita/master/mita.setup
6. Select the new *Mita* project, which will appear in *Github Projects* -> *<User>* -> *Mita* and continue by clicking on *Next*.
7. Choose a *Installation folder name* like "mita-master", which should be set by default and click on *Next*.
8. The setup is done. Click on *Finish* and the installation will be executed.
9. After this, a new Eclipse will be started. With the initial execution some *Setup Tasks* need to be executed. You can see the progress by clicking on the double arrow symbol on the bottom right. After finishing the *Setup Tasks* your environment is ready to use and should contain no errors.

### Write and run tests
Fixing a bug or introducing a new feature usually comes with writing a unit test to ensure that the new functionality will be still working in future. There are currently two test suites, one for testing code generators, and one for language specific tests:
* Code Generator Tests: org.eclipse.mita.program.generator.tests.AllTests
* Language (Xpect) Tests: org.eclipse.mita.program.tests.AllTests

Both test suites can be run from within your Eclipse workspace via `right-click -> Run As -> JUnit Plugin Tests`

### Create pull request
In order to create a pull request you need a GitHub account as well as an Eclipse account.
1. Create your own fork of this repository.
2. Switch your git remote origin to reference your fork. You can do this in Eclipse: In the properties of the git repository just change the value of remote origin url.
3. [Sign off](https://git-scm.com/docs/git-commit#git-commit--s) your commits using the same email address you are using for your Eclipse account.
4. Push the branch into your fork repository
5. Create a pull request here on GitHub by selecting your branch
