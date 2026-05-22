# vibe-desktop OnDemand Application 

The vibe-desktop provides a XFCE desktop environment inside an Apptainer container for Open OnDemand.
It determines the job name from the SLURM working directory and uses it as environment name. This allows for different versions of the desktop to be run simutaniously without interference.

## Building the desktop container

The Apptainer definition file to build the desktop container is located inside the 'apptainer_definition_files' folder. Build it as described by [Apptainer(https://apptainer.org/docs/user/main/build_a_container.html)], make it available to the user and point the 'container_path' inside submit.yml.erb to it.

## Deploying the Open OnDemand Application
Follow the documentation of [Open OnDemand on Application Management](https://osc.github.io/ood-documentation/latest/customizations.html#enabling-and-disabling-applications) to learn how to deploy this App on your OnDemand installation.

## Desktop Scripts
The VIBE desktop uses bash scripts to customize the user experience. The current implementation expects these scripts to be available inside the environment-specific folder (e.g. via symlink) of the network share.

**application_launcher.sh**  
Wrapper script for launching the [VIBE application containers](https://github.com/dsl-unibe-ch/vibe-applications).
It allows to handle application-specific operations like configurations, logging and so on.

**menu_builder.sh**  
Script that creates the files to provide a customized menu structure inside the XFCE application menu. Relies on the *application_launcher.sh* script to be availabale to the user to launch the containerized applications.

**user_login_script.sh**  
This script is required by the *submit.sh.erb* template of the OnDemand Application. It sets up the customized environment for the user (environment variables, wallpapers, menu files, default applications).

## Additional Information
More information about VIBE can be found in the [VIBE Documentation](https://dsl-unibe-ch.github.io/vibe-documentation/).
