#!/bin/sh -e

# Create configuration directory
# ----------------------------------------
  if [ ! -s /home/rancher/conf ]                                                                                                                                                                                                             
  then
    mkdir -p /home/rancher/conf
    chmod u=rwXt,go= /home/rancher/conf
    wget -O '/home/rancher/conf/cloud-config.yml' 'https://raw.githubusercontent.com/huggla/kstad-cloud-inits/master/rancherserver.yml'
    chmod u=rwt,go= /home/rancher/conf/cloud-config.yml
  fi

# Copy persistent ssh configuration
# ---------------------------------
  sshDir="/home/rancher/conf/ssh"
  if [ ! -s $sshDir ]
  then
    cp -rfp /etc/ssh $sshDir
  elif [ "$(ls -A $sshDir)" ]
  then
    cp -rfp $sshDir/* /etc/ssh/
  fi

# Copy persistent rc.local
# ------------------------
  if [ ! -s /home/rancher/conf/rc.local ]
  then
    echo '#!/bin/sh -e' > /home/rancher/conf/rc.local
    chmod u=rwxt,go= /home/rancher/conf/rc.local
  fi
  cp /home/rancher/conf/rc.local /etc/rc.local

# Set rancher user password (optional)
# ------------------------------------
  if [ ! -s /home/rancher/conf/set.rancher.pw ]
  then
    encryptedPasswd='$5$kqWRisDE.YYUtQVW$WbaZqT/upkxe4suRdB7IOdqyx77lyWNpi3WOMzUtR8D'
    touch /home/rancher/conf/set.rancher.pw
    chmod u=rwxt,go= /home/rancher/conf/set.rancher.pw
    echo '#!/bin/sh -e' > /home/rancher/conf/set.rancher.pw
    echo "echo 'rancher:$encryptedPasswd' | chpasswd -e" >> /home/rancher/conf/set.rancher.pw
  fi
  /bin/sh -c '/home/rancher/conf/set.rancher.pw' &

# Initiate zram swap (optional)
# -----------------------------
# if [ ! -s /home/rancher/conf/init.zram.swap ]
# then
#   echo '#!/bin/sh -e' > /home/rancher/conf/init.zram.swap
#   echo 'totalCpu=`cat /proc/cpuinfo | grep -ce "^processor"`' >> /home/rancher/conf/init.zram.swap
#   echo 'totalMem=`cat /proc/meminfo | grep -e "^MemTotal:" | sed -e "s/^MemTotal: *//" -e "s/  *.*//"`' >> /home/rancher/conf/init.zram.swap
#   echo 'zramFraction=75' >> /home/rancher/conf/init.zram.swap
#   echo 'ros service enable kernel-extras' >> /home/rancher/conf/init.zram.swap
#   echo 'ros service up kernel-extras' >> /home/rancher/conf/init.zram.swap
#   echo 'modprobeArgs="num_devices=$totalCpu"' >> /home/rancher/conf/init.zram.swap
#   echo 'modprobe zram $modprobeArgs' >> /home/rancher/conf/init.zram.swap
#   echo 'zMem=$(((totalMem * zramFraction / 100 / totalCpu) * 1024))' >> /home/rancher/conf/init.zram.swap
#   echo 'i=0' >> /home/rancher/conf/init.zram.swap
#   echo 'while [ $i -lt $totalCpu ]' >> /home/rancher/conf/init.zram.swap
#   echo 'do' >> /home/rancher/conf/init.zram.swap
#   echo '  echo $zMem > /sys/block/zram$i/disksize' >> /home/rancher/conf/init.zram.swap
#   echo '  mkswap /dev/zram$i' >> /home/rancher/conf/init.zram.swap
#   echo '  swapon -p 5 /dev/zram$i' >> /home/rancher/conf/init.zram.swap
#   echo '  i=$[$i+1]' >> /home/rancher/conf/init.zram.swap
#   echo 'done' >> /home/rancher/conf/init.zram.swap
#   echo 'exit 0' >> /home/rancher/conf/init.zram.swap
#   chmod u=rwxt,go= /home/rancher/conf/init.zram.swap
# fi
# /bin/sh -c '/home/rancher/conf/init.zram.swap' &

# Merge persistent cloud-config.yml (optional)
# --------------------------------------------
  if [ -s /home/rancher/conf/cloud-config.yml ]
  then
    ros config merge < /home/rancher/conf/cloud-config.yml
    hostname `ros config get hostname`
    ros service restart network
  fi

# Start Open VMware Tools (optional)
# ----------------------------------
# /bin/sh -c 'ros service enable open-vm-tools && ros service up open-vm-tools' &
                                                                         
# Start Rancher Server (optional)                                              
# -------------------------------                                                       
  mkdir /home/rancher/rancher-db                                                   
  chmod u=rwXt,go= /home/rancher/rancher-db                               
  mount -t ext4 /dev/disk/by-label/rancher-db /home/rancher/rancher-db                                    
  echo 'wait-for-docker' >> /etc/rc.local                                          
  echo 'docker run -d --restart=unless-stopped -p 8080:8080 -v /home/rancher/rancher-db:/var/lib/mysql rancher/server:stable > /var/log/rancherserver-start.log 2>&1 &' >> /etc/rc.local
                                                      
# Start Rancher Agent (optional)                                                                                                                                                        
# ------------------------------                                   
# if [ ! -s /home/rancher/conf/cattle_host_labels ]                       
# then                                                        
#   touch /home/rancher/conf/cattle_host_labels                    
#   chmod u=rwt,go= /home/rancher/conf/cattle_host_labels                            
# fi                                                                    
# if [ ! -s /home/rancher/conf/host_registration_url ]   
# then                                                                                                                                                                                    
#   touch /home/rancher/conf/host_registration_url    
#   chmod u=rwt,go= /home/rancher/conf/host_registration_url
# else                                                        
#   mkdir /var/lib/rancher/state                                                     
#   if [ ! -d "/home/rancher/conf/state" ]             
#   then                                                                
#     mkdir /home/rancher/conf/state                     
#     chmod -R u=rwXt,go= /home/rancher/conf/state                                                                                                                                        
#   fi                                                
#   mount -o bind /home/rancher/conf/state /var/lib/rancher/state
#   read cattleHostLabels < /home/rancher/conf/cattle_host_labels  
#   read hostRegistrationUrl < /home/rancher/conf/host_registration_url
#   echo 'wait-for-docker' >> /etc/rc.local                      
#   echo "docker run -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -e 'CATTLE_HOST_LABELS=$cattleHostLabels' rancher/agent $hostRegistrationUrl > /var/log/rancheragent-start.log 2>&1 &" >> /etc/rc.local
# fi                                                     
                                                                                                                                                                                                                       
exit 0
