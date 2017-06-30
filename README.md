# README #

The matlab-geoChemistry repository contains tools for the solution of equilibrium geochemical systems including aqueous and surface chemistry for use in batch and transport settings. 

### Summary ###

The main function of this repository, ChemicalModel.m, allows the creation and solution of arbitrarily complex aqueous chemistry systems including a number of surface chemistry models assuming local chemical equilibrium. The function leverages the tools developed by the SINTEF [MRST team](http://www.sintef.no/projectweb/mrst/) including [automatic differentiation](https://en.wikipedia.org/wiki/Automatic_differentiation). The chemical model created can be used to calculate batch reaction or can be coupled to flow within MRST.

### Installation ###

1. Install [MRST](http://www.sintef.no/projectweb/mrst/downloadable-resources/). 
2. Add the matlab-geoChemistry folder to the module folder of MRST.
3. Create a file named startup_user.m within the MRST folder, at the same level as startup.m.
4. In startup_user.m add then line
~~~~
mrstPath('register', 'geochemistry', 'path/to/repo/matlab-geochemistry')
~~~~

### Use ###

Once MRST is installed and made aware of the location of matlab-geoChemistry the module can be used like any other MRST module. 

Before any script that relies on the repository is run, MRST must be started. This is done by running the file startup.m inside of your MRST directory.

To use the geochemistry module in a Matlab script include the command

~~~~~
mrstModule add geochemistry
~~~~~

this will make the contents of the geochemistry directory available in the workspace.

## Functionality ##

ChemModel.m