#!/bin/bash

# Copyright 2011 Henrik Ingo <henrik.ingo@openlife.cc>
# License = GPLv2 or later
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 or later of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#set -e

# Check for a local cached configuration.
if test -f /etc/buildslave; then
    . /etc/buildslave
fi

# These parameters should be set and exported in the user-data script that
# calls us.  If they are not there, we set some defaults but they almost
# certainly will not work.
if test ! "$BB_MASTER"; then
    BB_MASTER="34.210.130.225:9989"
fi
if test ! "$BB_NAME"; then
    BB_NAME=$(hostname)
fi
if test ! "$BB_PASSWORD"; then
    BB_PASSWORD="password"
fi
if test ! "$BB_ADMIN"; then
    BB_ADMIN="Automated spack BuildBot slave <EMAIL>"
fi
if test ! "$BB_DIR"; then
    BB_DIR="/var/lib/buildbot/slaves/cdash_spack"
fi
if test ! "$BB_USE_PIP"; then
    BB_USE_PIP=1
fi
if test ! "$BB_URL"; then
    BB_URL="https://raw.githubusercontent.com/kielfriedt/spack-buildbot-config/master/scripts/"
fi
if test ! "$SPACK_URL"; then
    SPACK_URL="https://spack.io/cdash/submit.php?project=spack"
fi
if test ! "$XSDK_URL"; then
    XSDK_URL="https://spack.io/cdash/submit.php?project=xsdk"
fi
if test ! "$WEEKLY_URL"; then
    WEEKLY_URL="https://spack.io/cdash/submit.php?project=weekly"
fi

if test ! -f /etc/buildslave; then
    echo "SPACK_URL=\"$SPACK_URL\""      > /etc/buildslave
    echo "WEEKLY_URL=\"$WEEKLY_URL\""   >> /etc/buildslave
    echo "XSDK_URL=\"$XSDK_URL\""       >> /etc/buildslave
    echo "BB_MASTER=\"$BB_MASTER\""     >> /etc/buildslave
    echo "BB_NAME=\"$BB_NAME\""         >> /etc/buildslave
    echo "BB_PASSWORD=\"$BB_PASSWORD\"" >> /etc/buildslave
    echo "BB_ADMIN=\"$BB_ADMIN\""       >> /etc/buildslave
    echo "BB_DIR=\"$BB_DIR\""           >> /etc/buildslave
    echo "BB_URL=\"$BB_URL\""           >> /etc/buildslave
fi

BB_PARAMS="${BB_DIR} ${BB_MASTER} ${BB_NAME} ${BB_PASSWORD}"
echo "$0: BB_PARAMS is now $BB_PARAMS"
echo "$0: BB_URL is now $BB_URL"

set -x

# Magic IP address from where to obtain EC2 metadata
# Do not need to change it is defined by amazon
METAIP="169.254.169.254" 
METAROOT="http://${METAIP}/latest"
# Don't print 404 error documents. Don't print progress information.
CURL="curl --fail --silent"


testbin () {
    BIN_PATH="$(which ${1})"
    if [ ! -x "${BIN_PATH}" -o -z "${BIN_PATH}" ]; then
            return 1
    fi
    return 0
}

case "$BB_NAME" in

Amazon*)
    yum -y install deltarpm gcc python-pip python-devel
    easy_install --quiet buildbot-slave
    BUILDSLAVE="/usr/local/bin/buildslave"
    sudo yum -y install compat-gcc-44-*

    # User buildbot needs to be added to sudoers and requiretty disabled.
    if ! id -u buildbot >/dev/null 2>&1; then
        adduser buildbot
        echo "buildbot  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        sed -i.bak 's/ requiretty/ !requiretty/' /etc/sudoers
        sed -i.bak '/secure_path/d' /etc/sudoers
    fi
    ;;

CentOS*)
    sudo yum -y install compat-gcc-44-* 
    if cat /etc/redhat-release | grep -Eq "6."; then
        # The buildbot-slave package isn't available from a common repo.
        BUILDSLAVE_URL="http://build.lustre.org"
        BUILDSLAVE_RPM="buildbot-slave-0.8.8-2.el6.noarch.rpm"
        sudo yum -y install $BUILDSLAVE_URL/$BUILDSLAVE_RPM
        BUILDSLAVE="/usr/bin/buildslave"
    else
        sudo yum -y install deltarpm gcc python-pip python-devel
        easy_install --quiet buildbot-slave
        BUILDSLAVE="/usr/bin/buildslave"
    fi

    # User buildbot needs to be added to sudoers and requiretty disabled.
    if ! id -u buildbot >/dev/null 2>&1; then
        adduser buildbot
    fi

    echo "buildbot  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    sed -i.bak 's/ requiretty/ !requiretty/' /etc/sudoers
    sed -i.bak '/secure_path/d' /etc/sudoers
    ;;

Debian*)
    apt-get --yes update
    sudo apt-get --yes install gcc-5 gcc-4.7 gcc-4.8 gcc-4.9
    # Relying on the pip version of the buildslave is more portable but
    # slower to bootstrap.  By default prefer the packaged version.
    if test $BB_USE_PIP -ne 0; then
        apt-get --yes install gcc curl python-pip python-dev
        pip --quiet install buildbot-slave
        BUILDSLAVE="/usr/local/bin/buildslave"
    else
        apt-get --yes install curl buildbot-slave
        BUILDSLAVE="/usr/bin/buildslave"
    fi

    # User buildbot needs to be added to sudoers and requiretty disabled.
    if ! id -u buildbot >/dev/null 2>&1; then
        adduser --disabled-password --gecos "" buildbot
    fi

    echo "buildbot  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    sed -i.bak 's/ requiretty/ !requiretty/' /etc/sudoers
    sed -i.bak '/secure_path/d' /etc/sudoers
    ;;

RHEL*)
    sudo yum -y install deltarpm gcc python-pip python-devel
    easy_install --quiet buildbot-slave
    BUILDSLAVE="/usr/bin/buildslave"
    # User buildbot needs to be added to sudoers and requiretty disabled.
    yum -y install compat-gcc-44-*
    if ! id -u buildbot >/dev/null 2>&1; then
        adduser buildbot
        echo "buildbot  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        sed -i.bak 's/ requiretty/ !requiretty/' /etc/sudoers
        sed -i.bak '/secure_path/d' /etc/sudoers
    fi
    ;;

Ubuntu*)
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ECDCAD72428D7C01
    while [ -s /var/lib/dpkg/lock ]; do sleep 1; done
    sudo apt-get --yes update
    # Relying on the pip version of the buildslave is more portable but
    # slower to bootstrap.  By default prefer the packaged version.
    if test $BB_USE_PIP -ne 0; then
        sudo apt-get --yes install python-pip python-dev
        sudo pip --quiet install buildbot-slave requests
        BUILDSLAVE="/usr/local/bin/buildslave"
    else
        apt-get --yes install buildbot-slave
        BUILDSLAVE="/usr/bin/buildslave"
    fi
    
    # Install the latest kernel to reboot on to.
    if test "$BB_MODE" = "TEST" -o "$BB_MODE" = "PERF"; then
        apt-get --yes install --only-upgrade linux-image-generic
    fi

    # User buildbot needs to be added to sudoers and requiretty disabled.
    if ! id -u buildbot >/dev/null 2>&1; then
        adduser --disabled-password --gecos "" buildbot
    fi

    echo "buildbot  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    sed -i.bak 's/ requiretty/ !requiretty/' /etc/sudoers
    sed -i.bak '/secure_path/a\Defaults exempt_group+=buildbot' /etc/sudoers
    ;;

    # Standardize ephemeral storage so it's available under /mnt.
    # This is the default.

*)
    echo "Unknown distribution, cannot bootstrap $BB_NAME"
    ;;
esac

# Generic buildslave configuration
if test ! -d $BB_DIR; then
    mkdir -p $BB_DIR
    chown buildbot.buildbot $BB_DIR
    sudo -u buildbot $BUILDSLAVE create-slave --umask=022 --usepty=0 $BB_PARAMS
fi

# Extract some of the EC2 meta-data and make it visible in the buildslave
echo $BB_ADMIN > $BB_DIR/info/admin
$CURL "${METAROOT}/meta-data/public-hostname" > $BB_DIR/info/host
echo >> $BB_DIR/info/host
$CURL "${METAROOT}/meta-data/instance-type" >> $BB_DIR/info/host
echo >> $BB_DIR/info/host
$CURL "${METAROOT}/meta-data/ami-id" >> $BB_DIR/info/host
echo >> $BB_DIR/info/host
$CURL "${METAROOT}/meta-data/instance-id" >> $BB_DIR/info/host
echo >> $BB_DIR/info/host
uname -a >> $BB_DIR/info/host
grep MemTotal /proc/meminfo >> $BB_DIR/info/host
grep 'model name' /proc/cpuinfo >> $BB_DIR/info/host
grep 'processor' /proc/cpuinfo >> $BB_DIR/info/host

# Finally, start it.
sudo -u buildbot $BUILDSLAVE start $BB_DIR

# If all goes well, at this point you should see a buildbot slave joining your
# farm.  You can then manage the rest of the work from the buildbot master.
