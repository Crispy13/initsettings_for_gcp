#! /bin/bash

#!! You must run this script with sudo permission. !!#
### Preset
target_server=111.111.111.111.111
username="eck"
iwd=$(pwd)

### Notice
cat <<EOF

===== Initial Server Settings v0.3 made on March 8 2020. =====

This script will require sudo password in order to make folders at root folder and use apt install command.
This script will do the followings:
	- Update ubuntu packages
	- Set timezone as Asia/Seoul
	- Ssh keygen and copy it to $target_server.
	- Make data directory and subdirectories.
	- Change ownership of part of new directories.
	- Update bashrc.
	- Install lsyncd, htop, ncdu.
	- Make update_from_targetserver.sh, lsyncd.conf, snubh-1.13.txt(exported conda list).

Additional Processes were needed to set workspace after running this script:
	- Install Nvidia drivers.
	- Install Anaconda.
	- Build conda environments.

EOF
printf "Do you want to continue this script? [yes|no]\\n"
printf "[no] >>> "
read -r ans
while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
      [ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
do
	printf "Please answer 'yes' or 'no':'\\n"
	printf ">>> "
	read -r ans
done
if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]
then
    printf "Aborting settings.\\n"
    exit 2
fi

### Check if InitSettings has run already on this account.
if [ -f "$HOME/.InitSettings_has_been_run" ]; then
	echo ""
	echo "It seems that InitSettings.sh has been run more than or equal one time."
	echo "Running this script more than one time is not recommended. It should corrupt your system."
	echo "Do you want to continue? [yes|no]"

	printf "[no] >>> "
	read -r ans
	while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
	      [ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
	do
		printf "Please answer 'yes' or 'no':'\\n"
		printf ">>> "
		read -r ans
	done
	if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]
	then
	    printf "Aborting settings.\\n"
	    exit 2
	fi
fi

printf "\\n"
printf "Starting processes...\\n\\n"
sleep 2

### Record run count
echo "InitSettings has been run. $(date +%Y%m%d%H%M%S)" >> $HOME/.InitSettings_has_been_run

### Update packages
sudo apt update
sudo apt upgrade -y
printf ">> Package update has been done.\\n\\n"

### Set timezone as Asia/Seoul
sudo timedatectl set-timezone Asia/Seoul
echo ">> Timezone was set to Asia/Seoul."

### Ssh keygen
echo -e ">> Ssh keygen process, target server : $target_server\n"
ssh-keygen -t rsa -b 4096 -C "eck@$(hostname)" -f /home/eck/.ssh/id_rsa
ssh-copy-id eck@$target_server

### Make folders
echo ">> Making folders..."
sudo mkdir -p /data/eck
sudo chown -R eck:eck /data/eck

mkdir -p /data/eck/Downloads
mkdir -p /data/eck/Workspace
mkdir -p /data/eck/temp
mkdir -p /data/eck/software/bin


### Update bashrc
# sed -i "/# >>> Custom Settings >>>/,/# <<< Custom Settings <<</d" ~/.bashrc # Not used.
cat <<EOT >> ~/.bashrc

# >>> Custom Settings >>>
cd /data/eck/

export eck="/data/eck"
export TMPDIR="/data/eck/temp/"
export PYTHONPATH="\$PYTHONPATH:/data/eck/Workspace/Custom_Modules"

alias da="conda deactivate"
alias ju="conda activate jupyter"
alias jup="jupyter lab"
alias sn="conda activate snubh-1.13"
alias cl="ps -ef | grep 'lsyncd'" # Check lsyncd

PATH="/data/eck/software/bin:\$PATH"

function sl {
	echo "Terminating all lsyncd jobs..."
        lpid=\$(ps -ef | grep "lsyncd" | grep -v "grep" | tr -s " " | cut -f 2 -d " ")
        if [ "\$lpid" = "" ]
        then
                echo "lsyncd is not running."
        else
                kill -9 \$lpid
                echo "\$lpid has been terminated."
        fi
}

function csv_viewer {
        column -s, -t < $1 | less -#2 -N -S
}

# Launch lsyncd on startup.
if ! [ -x "\$(command -v lsyncd)" ]
then
        echo "Error: lsyncd was not found."
else
	lpid=\$(ps -ef | grep "lsyncd" | grep -v "grep" | tr -s " " | cut -f 2 -d " ")
	if [ "\$lpid" = "" ]
	then
		lsyncd \$eck/lsyncd.conf
	fi
fi

# <<< Custom Settings <<<

EOT

### Install softwares
echo "Installing softwares with apt install..."
sudo apt update
sudo apt install -y htop ncdu cmake lua5.3 liblua5.3-dev liblua5.3-0 pigz

# > lsyncd
git clone https://github.com/axkibe/lsyncd.git /data/eck/Downloads/lsyncd
cd /data/eck/Downloads/lsyncd
cmake .
make
make install DESTDIR=/data/eck/software/lsyncd
ln -s /data/eck/software/lsyncd/usr/local/bin/lsyncd /data/eck/software/bin/lsyncd

cd $iwd
rm -rf /data/eck/Downloads/lsyncd
# lsyncd <

echo ">> Installing softwares has been done."

### Make lsyncd.config file
cat <<EOT > /data/eck/lsyncd.conf
settings {
    logfile = "/data/eck/lsyncd.log",
    statusFile = "/data/eck/lsyncd-status.log",
    statusInterval = 20
}

sync {
   default.rsyncssh,
   source="/data/eck/Workspace",
   host="eck@203.230.60.184",
   targetdir="/data/eck/backup/$(hostname)",
   delete=false,
   exclude={ "*.pkl" },
   rsync = {
     archive = true,
     compress = false,
     whole_file = false,
     backup = false,
     suffix = "_backup",
     update = true
   },
   ssh = {
     port = 22
   }
}
EOT

echo ">> lsyncd.conf file has been made."

### Make update_from_targetserver.sh
cat <<EOT > /data/eck/Workspace/update_from_targetserver.sh
#! /bin/bash

scp -r eck@$target_server:/data/eck/Workspace/Custom_Modules /data/eck/Workspace/
scp -r eck@$target_server:/data/eck/Workspace/snubh/*.ipynb /data/eck/Workspace/snubh
scp -r eck@$target_server:/data/eck/Workspace/snubh/*.py /data/eck/Workspace/snubh
echo ">> Done."
EOT

echo ">> update_from_targetserver.sh has been made."

### Make snubh-1.13.txt file
cat <<EOT > /data/eck/snubh-1.13.txt
# This file may be used to create an environment using:
# $ conda create --name <env> --file <this file>
# platform: linux-64
_libgcc_mutex=0.1=main
_tflow_select=2.1.0=gpu
absl-py=0.8.1=py37_0
asn1crypto=1.2.0=py37_0
astor=0.8.0=py37_0
backcall=0.1.0=py37_0
blas=1.0=mkl
blinker=1.4=py37_0
bzip2=1.0.8=h7b6447c_0
c-ares=1.15.0=h7b6447c_1001
ca-certificates=2020.1.1=0
cachetools=3.1.1=py_0
cairo=1.14.12=h8948797_3
certifi=2019.11.28=py37_0
cffi=1.13.2=py37h2e261b9_0
chardet=3.0.4=py37_1003
cloudpickle=1.2.2=py_0
cryptography=2.8=py37h1ba5d50_0
cudatoolkit=10.0.130=0
cudnn=7.6.5=cuda10.0_0
cupti=10.0.130=0
cycler=0.10.0=py37_0
cytoolz=0.10.1=py37h7b6447c_0
dask-core=2.9.0=py_0
dbus=1.13.12=h746ee38_0
decorator=4.4.1=py_0
expat=2.2.6=he6710b0_0
ffmpeg=4.0=hcdf2ecd_0
fontconfig=2.13.0=h9420a91_0
freeglut=3.0.0=hf484d3e_5
freetype=2.9.1=h8a8886c_1
fribidi=1.0.5=h7b6447c_0
gast=0.3.2=py_0
glib=2.63.1=h5a9c865_0
google-api-python-client=1.7.11=py_0
google-auth=1.8.2=py_0
google-auth-httplib2=0.0.3=py_2
google-auth-oauthlib=0.4.1=py_0
graphite2=1.3.13=h23475e2_0
graphviz=2.40.1=h21bd128_2
grpcio=1.16.1=py37hf8bcb03_1
gst-plugins-base=1.14.0=hbbd80ab_1
gstreamer=1.14.0=hb453b48_1
h5py=2.8.0=py37h989c5e5_3
harfbuzz=1.8.8=hffaf4a1_0
hdf5=1.10.2=hba1933b_1
httplib2=0.14.0=py37_0
icu=58.2=h9c2bf20_1
idna=2.8=py37_0
imageio=2.6.1=py37_0
intel-openmp=2019.4=243
ipykernel=5.1.3=py37h39e3cac_0
ipython=7.10.2=py37h39e3cac_0
ipython_genutils=0.2.0=py37_0
jasper=2.0.14=h07fcdf6_1
jedi=0.15.1=py37_0
joblib=0.14.1=py_0
jpeg=9b=h024ee3a_2
jupyter_client=5.3.4=py37_0
jupyter_core=4.6.1=py37_0
keras=2.2.4=0
keras-applications=1.0.8=py_0
keras-base=2.2.4=py37_0
keras-preprocessing=1.1.0=py_1
kiwisolver=1.1.0=py37he6710b0_0
libedit=3.1.20181209=hc058e9b_0
libffi=3.2.1=hd88cf55_4
libgcc-ng=9.1.0=hdf63c60_0
libgfortran-ng=7.3.0=hdf63c60_0
libglu=9.0.0=hf484d3e_1
libopencv=3.4.2=hb342d67_1
libopus=1.3=h7b6447c_0
libpng=1.6.37=hbc83047_0
libprotobuf=3.11.2=hd408876_0
libsodium=1.0.16=h1bed415_0
libstdcxx-ng=9.1.0=hdf63c60_0
libtiff=4.0.10=h2733197_2
libuuid=1.0.3=h1bed415_2
libvpx=1.7.0=h439df22_0
libxcb=1.13=h1bed415_1
libxml2=2.9.9=hea5a465_1
llvmlite=0.30.0=py37hd408876_0
markdown=3.1.1=py37_0
matplotlib=3.1.1=py37h5429711_0
matplotlib-venn=0.11.5=py_1
mkl=2019.4=243
mkl-service=2.3.0=py37he904b0f_0
mkl_fft=1.0.15=py37ha843d7b_0
mkl_random=1.1.0=py37hd6b4f25_0
mock=3.0.5=py37_0
ncurses=6.1=he6710b0_1
networkx=2.4=py_0
numba=0.46.0=py37h962f231_0
numpy=1.17.4=py37hc1035e2_0
numpy-base=1.17.4=py37hde5b4d6_0
oauthlib=3.1.0=py_0
olefile=0.46=py37_0
opencv=3.4.2=py37h6fd60c2_1
openssl=1.1.1d=h7b6447c_4
pandas=0.25.3=py37he6710b0_0
pango=1.42.4=h049681c_0
parso=0.5.2=py_0
patsy=0.5.1=py37_0
pcre=8.43=he6710b0_0
pexpect=4.7.0=py37_0
pickleshare=0.7.5=py37_0
pillow=6.2.1=py37h34e0f95_0
pip=19.3.1=py37_0
pixman=0.38.0=h7b6447c_0
prompt_toolkit=3.0.2=py_0
protobuf=3.11.2=py37he6710b0_0
ptyprocess=0.6.0=py37_0
py-opencv=3.4.2=py37hb342d67_1
pyasn1=0.4.8=py_0
pyasn1-modules=0.2.7=py_0
pycparser=2.19=py37_0
pydot=1.4.1=py37_0
pydotplus=2.0.2=py37_1
pygments=2.5.2=py_0
pyjwt=1.7.1=py37_0
pyopenssl=19.1.0=py37_0
pyparsing=2.4.5=py_0
pyqt=5.9.2=py37h05f1152_2
pysocks=1.7.1=py37_0
python=3.7.5=h0371630_0
python-dateutil=2.8.1=py_0
pytz=2019.3=py_0
pywavelets=1.1.1=py37h7b6447c_0
pyyaml=5.2=py37h7b6447c_0
pyzmq=18.1.0=py37he6710b0_0
qt=5.9.7=h5867ecd_1
readline=7.0=h7b6447c_5
requests=2.22.0=py37_1
requests-oauthlib=1.3.0=py_0
rsa=4.0=py_0
scikit-image=0.15.0=py37he6710b0_0
scikit-learn=0.21.3=py37hd81dba3_0
scipy=1.3.2=py37h7c811a0_0
seaborn=0.9.0=pyh91ea838_1
setuptools=42.0.2=py37_0
simpleitk=1.2.3=py37hf484d3e_0
simplejson=3.17.0=py37h7b6447c_0
sip=4.19.8=py37hf484d3e_0
six=1.13.0=py37_0
sqlite=3.30.1=h7b6447c_0
statsmodels=0.10.1=py37hdd07704_0
tbb=2019.8=hfd86e86_0
tensorboard=1.13.1=py37hf484d3e_0
tensorflow=1.13.1=gpu_py37hc158e3b_0
tensorflow-base=1.13.1=gpu_py37h8d69cac_0
tensorflow-estimator=1.13.0=py_0
tensorflow-gpu=1.13.1=h0d30ee6_0
termcolor=1.1.0=py37_1
tk=8.6.8=hbc83047_0
toolz=0.10.0=py_0
tornado=6.0.3=py37h7b6447c_0
traitlets=4.3.3=py37_0
uritemplate=3.0.0=py_1
urllib3=1.25.7=py37_0
wcwidth=0.1.7=py37_0
werkzeug=0.16.0=py_0
wheel=0.33.6=py37_0
xz=5.2.4=h14c3975_4
yaml=0.1.7=had09818_2
zeromq=4.3.1=he6710b0_3
zlib=1.2.11=h7b6447c_3
zstd=1.3.7=h0b5b093_0
EOT

echo ">> snubh-1.13.txt file has been copied."

echo ""
echo -e "All process has been done.\n"

### End of this script ###
