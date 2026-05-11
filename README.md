# vibe-desktop OnDemand Application 

The vibe-desktop provides a XFCE desktop environment inside an Apptainer container.
It determines the job name from the SLURM working directory and uses it as environment name. This allows for different versions of the desktop to be run simutaniously without interference.

## Building the desktop container

The Apptainer definition file to build the desktop container is located inside the 'apptainer_definition_files' folder. Build it as described by [Apptainer(https://apptainer.org/docs/user/main/build_a_container.html)], make it available to the user and point the 'container_path' inside submit.yml.erb to it.

## Requirements

The desktop container requires the user_login_script.sh from the [vibe-utilities repository(https://github.com/dsl-unibe-ch/vibe-utilities)] to setup the user profile.

## License

* Code is licensed under BSD-3 (see LICENSE.md)
