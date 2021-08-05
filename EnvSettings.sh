#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Check if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
then
	echo "script ${BASH_SOURCE[0]} is being sourced ..."
else
	echo "This script should be sourced. Please run this script using '.' or 'source'"
	exit 1
fi

# Check if conda exists.
if ! [ -x "$(command -v conda)" ]
then
        echo "Error: conda was not found. You should install and set anaconda first, before using this script."
        echo "Aborting setting."
        return 1
fi


# Create conda environments
echo ">> Creating conda environment, 'jupyter' ..."
conda create -n jupyter jupyterlab nb_conda -y 
echo ">> Done."

echo ">> Creating conda environment, 'snubh-1.13' ..."
conda create -n snubh-1.13 --file /data/eck/snubh-1.13.txt -c conda-forge -c simpleitk -y
echo ">> Done."

# Activate jupyterlab
# source /data/eck/software/anaconda3/bin/activate jupyter
conda activate jupyter
echo ">> Jupyter env has been activated."

# Check if jupyter exists.
if ! [ -x "$(command -v jupyter)" ]
then
        echo "Error: Jupyter was not found. You should run this script after installing jupyter and activating the env where jupyter was installed."
	echo "Aborting setting."
        return 1
fi

# Generate config and set password
echo ">> Generating config and setting password..."
jupyter notebook --generate-config
jupyter notebook password

# Edit jupyter settings py
sed -i -e "s/#c.NotebookApp.ip = 'localhost'/c.NotebookApp.ip = '0.0.0.0'/" $HOME/.jupyter/jupyter_notebook_config.py
sed -i -e "s/#c.NotebookApp.port = 8888/c.NotebookApp.port = 8899/" $HOME/.jupyter/jupyter_notebook_config.py
sed -i -e "s/#c.NotebookApp.open_browser = True/c.NotebookApp.open_browser = False/" $HOME/.jupyter/jupyter_notebook_config.py

mkdir -p $HOME/.jupyter/lab/
tar xvf $DIR/lab-user-settings.tgz -C $HOME/.jupyter/lab/

conda deactivate
echo "Jupyter Settings have been applied."
