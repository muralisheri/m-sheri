# Add an alias for running the chef-client if needed

# Add an alias for running the chef-client to update the application
echo "#!/bin/bash

sudo /bin/mkdir /efs; sudo sudo mount -t nfs4 -o nfsvers=4.1 $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone).fs-2fa66066.efs.us-east-1.amazonaws.com: /efs" >> /usr/local/bin/arcc

chmod +x /usr/local/bin/arcc
echo "alias arcc='/usr/local/bin/arcc'" >> /root/.bashrc

