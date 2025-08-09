#!/bin/bash

# Pre-bootstrap user data
${pre_bootstrap_user_data}

# Bootstrap the node
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_extra_args}

# Post-bootstrap user data
${post_bootstrap_user_data}
