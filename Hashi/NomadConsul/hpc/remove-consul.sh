source ./configs/roles

hashi-up consul uninstall \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $USER \

hashi-up consul uninstall \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $USER \

hashi-up consul uninstall \
  --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $USER \

hashi-up consul uninstall \
  --ssh-target-addr $AGENT_1_IP \
  --ssh-target-user $USER \

hashi-up consul uninstall \
  --ssh-target-addr $AGENT_2_IP \
  --ssh-target-user $USER \
