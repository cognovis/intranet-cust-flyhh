intranet-cust-flyhh
===================

Please make sure that your object type 'flyhh_event_participant' is part of the list 'object_types' in ~/packages/intranet-core/tcl/intranet-core-init.tcl

Please make sure that your object type 'flyhh_event' is part of the list 'object_types' in ~/packages/intranet-core/tcl/intranet-core-init.tcl

Add restrict_edit_list parameter to running instances of the package:
Parameter Name: restrict_edit_list
Description: does not allow editing of fields other than the name, address, dance partner and room mates when the registration status id is found in this list, see also "Flyhh - Event Registration Status"
Default: 82503 82504 82505 82506

cd /var/lib/aolserver/
sudo ln -sf projop flyhh

sudo apt-get install html2ps
