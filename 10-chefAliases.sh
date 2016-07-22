# Add an alias for running the chef-client if needed

# Add an alias for running the chef-client if needed
echo "#!/bin/bash

sudo /usr/local/bin/sync-attributes; sudo chef-client -j /etc/chef/roles.json" >> /usr/local/bin/rcc

chmod +x /usr/local/bin/rcc
echo "alias rcc='/usr/local/bin/rcc'" >> /root/.bashrc

# Add an alias for running the chef-client to update the application
echo "#!/bin/bash

sudo /usr/local/bin/sync-attributes; sudo chef-client -j /etc/chef/roles.json -o media-shopatron::application" >> /usr/local/bin/arcc

chmod +x /usr/local/bin/arcc
echo "alias arcc='/usr/local/bin/arcc'" >> /root/.bashrc

# Add an alias for rolling back
echo "#!/bin/bash

sudo /usr/local/bin/sync-attributes; sudo chef-client -j /etc/chef/roles.json -o media-shopatron::rollback" >> /usr/local/bin/rollback

chmod +x /usr/local/bin/rollback
echo "alias rollback='/usr/local/bin/rollback'" >> /root/.bashrc
