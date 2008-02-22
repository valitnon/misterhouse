use strict;

package Serial_Item;

@Serial_Item::ISA = ('Generic_Item');

my (%serial_items_by_id);

sub reset {
    undef %serial_items_by_id;   # Reset on code re-load
}

sub serial_items_by_id {
    my($id) = @_;
    return unless $serial_items_by_id{$id};
    return @{$serial_items_by_id{$id}};
}
                                # For backward compatability, return just the first item
sub serial_item_by_id {
    my($id) = @_;
    my @refs = &serial_items_by_id($id);
    return $refs[0];
}

sub new {
    my ($class, $id, $state, $port_name) = @_;
    my $self = {state => undef}; # Use undef ... '' will return as defined
#   print "\n\nWarning: duplicate ID codes on different Serial_Item objects:\n " .
#         "id=$id state=$state states=@{${$serial_item_by_id{$id}}{states}}\n\n" if $serial_item_by_id{$id};
    $$self{port_name} = $port_name;
    &add($self, $id, $state);
    bless $self, $class;
    $self->set_interface($port_name) if $id and $id =~ /^X/;
    return $self;
}
sub add {
    my ($self, $id, $state) = @_;

                                # Allow for Serial_Item's without states
#   $state = 'default_state' unless defined $state;
    $state = $id  unless defined $state;

    $$self{state_by_id}{$id} = $state if defined $id;
    $$self{id_by_state}{$state} = $id if defined $state;
    push(@{$$self{states}}, $state);
    push(@{$serial_items_by_id{$id}}, $self) if $id;
}

sub is_started {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    return ($main::Serial_Ports{$port_name}{object}) ? 1 : 0;
}
sub is_stopped {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    return ($main::Serial_Ports{$port_name}{object}) ? 0 : 1;
}

                                # Try to do a 'new' ... object is not kept, even if new is sucessful
                                #   - not sure if there is a better way to test if a port is available
                                #     Hopefully this is not too wasteful
sub is_available {
    my ($self) = @_;

    my $port_name = $self->{port_name};
    my $port = $main::Serial_Ports{$port_name}{port};
    print "testing port $port ... ";

    my $sp_object;

                                # Use the 2nd parm of '1' to indicate this do a test open
                                #  - Modified Win32::SerialPort so it does not compilain if New/open fails
    if (( $main::OS_win and $sp_object = new Win32::SerialPort($port, 1))or 
        (!$main::OS_win and $sp_object = new Device::SerialPort($port))) {
        print " available\n";
        $sp_object->close;
        return 1;
    }
    else {
        print " not available\n";
        return 0;
    }
}

sub start {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    print "Starting port $port_name on port $main::Serial_Ports{$port_name}{port}\n";
    if ($main::Serial_Ports{$port_name}{object}) {
        print "Port $port_name is already started\n";
        return;
    }
    if ($port_name) {
        if (&main::serial_port_open($port_name)) {
            print "Port $port_name was re-opened\n";
        }
        else {
            print "Serial_Item start failed for port $port_name\n";
        }
    }
    else {
        print "Error in Serial_Item start:  no port name for object=$self\n";
    }
}

sub stop {
    my ($self) = @_;
    my $port_name = $self->{port_name};
    my $sp_object = $main::Serial_Ports{$port_name}{object};
    if ($sp_object) {

        my $port = $main::Serial_Ports{$port_name}{port};
#       &Win32::SerialPort::debug(1);
        if ($sp_object->close) {
            print "Port $port_name on port $port was closed\n";
        }
        else {
            print "Serial_Item stop failed for port $port_name\n";
        }
                                # Delete the ports, even if it didn't close, so we can do 
                                # starts again without a 'port reuse' message.
        delete $main::Serial_Ports{$port_name}{object};
        delete $main::Serial_Ports{object_by_port}{$port};
#       &Win32::SerialPort::debug(0);
    }
    else {
        print "Error in Serial_Item stop for port $port_name: Port is not started\n";
    }
}

sub said {
    my $port_name = $_[0]->{port_name};
    my $datatype  = $main::Serial_Ports{$port_name}{datatype};
    
    my $data;
    if ($datatype and $datatype eq 'raw') {
        $data = $main::Serial_Ports{$port_name}{data};
        $main::Serial_Ports{$port_name}{data} = '';
    }
    else {
        $data = $main::Serial_Ports{$port_name}{data_record};
        $main::Serial_Ports{$port_name}{data_record} = ''; # Maybe this should be reset in main loop??
    }
#   print "db serial $port_name data: $data\n" if $main::config_parms{debug} and $main::config_parms{debug} eq $port_name;
    return $data;
}

sub set_data {
    my ($self, $data) = @_;
    my $port_name = $self->{port_name};
    my $datatype  = $main::Serial_Ports{$port_name}{datatype};
    if ($datatype eq 'raw') {
        $main::Serial_Ports{$port_name}{data} = $data;
    }
    else {
        $main::Serial_Ports{$port_name}{data_record} = $data;
    }
}

sub set_receive {
    my ($self, $state) = @_;
    &Generic_Item::set_states_for_next_pass($self, $state, 'serial');
}

sub set_dtr {
    my ($self, $state) = @_;
    my $port_name = $self->{port_name};
    if (my $serial_port = $main::Serial_Ports{$port_name}{object}) {
        $main::Serial_Ports{$port_name}{object}->dtr_active($state);
        print "Serial_port $port_name dtr set to $state\n" if $main::config_parms{debug} eq 'serial';
    }
    else {
        print "Error, serial port set_dtr for $port_name failed, port has not been set\n";
    }
}
sub set_rts {
    my ($self, $state) = @_;
    my $port_name = $self->{port_name};
    if (my $serial_port = $main::Serial_Ports{$port_name}{object}) {
        $main::Serial_Ports{$port_name}{object}->rts_active($state);
        print "Serial_port $port_name rts set to $state\n" if $main::config_parms{debug} eq 'serial';
    }
    else {
        print "Error, serial port set_rts for $port_name failed, port has not been set\n";
    }
}


sub set {
    my ($self, $state) = @_;
    return if &main::check_for_tied_filters($self, $state);

                                # Allow for Serial_Item's without states
    unless (defined $state) {
        print "Serial_Item set with an empty state on $$self{object_name}\n";
        $state = 'default_state';
    }

    my $serial_id;
                                # Allow for upper/mixed case (e.g. treat ON the same as on ... so X10_Items is simpler)
    if (defined $self->{id_by_state}{$state}) {
        $serial_id = $self->{id_by_state}{$state};
    }
    elsif (defined $self->{id_by_state}{lc $state}) {
        $serial_id = $self->{id_by_state}{lc $state};
    }
    else {
        $serial_id = $state;
    }
    my $serial_data = $serial_id;

                                # Avoid sending the same X10 code on consecutive passes.
                                # It is pretty easy to create a loop with
                                # tied items, groups, house codes, etc.  Just ask Bill S. :)
#   print "db state=$state, sp=$self->{state_prev},  loop=$main::Loop_Count, lcp==$self->{change_pass}\n";
    if ($serial_id =~ /^X/ and $self->{state_prev} and $state eq $self->{state_prev} and 
        $self->{change_pass} >= ($main::Loop_Count - 1)) {
        my $item_name = $self->{object_name};
        print "X10 item set skipped on consecutive pass.  item=$item_name state=$state id=$serial_id\n";
        return;
    }

    &Generic_Item::set_states_for_next_pass($self, $state, 'serial');

    return unless %main::Serial_Ports;

    my $port_name = $self->{port_name};

    print "Serial_Item: port=$port_name self=$self state=$state data=$serial_data interface=$$self{interface}\n" 
        if $main::config_parms{debug} eq 'serial';

    return if $main::Save{mode} eq 'offline';

    my $interface = $$self{interface};
    $interface = 'none' unless $interface;

                                # First deal with X10 strings...
    if ($serial_data =~ /^X/ or $self->isa('X10_Item')) {
                                # allow for xx% (e.g. 1% -> &P1)
                                #  ... need to allow for multiple X10 commands data here?
        if ($serial_data =~ /(\d+)%/) {
            $serial_data = '&P' . int ($1 * 63 / 100 + 0.5);
        }
                                # Make sure that &P codes have the house code prefixed
                                #  - e.g. device A1 -> A&P1
        if ($serial_data =~ /&P/) {
            $serial_data = substr($self->{x10_id}, 1, 1) . $serial_data;
        }
                                # If code is &P##, prefix with item code.
                                #  - e.g. A&P1 -> A1A&P1
        if (substr($serial_data, 1, 1) eq '&') {
            $serial_data = $self->{x10_id} . $serial_data;
        }
   
        &main::print_log("X10: Outgoing data=$serial_data") if $main::config_parms{x10_errata} >= 4;

                                # Allow for long strings like this: XAGAGAGAG (e.g. SmartLinc control)
                                #  - break it into individual codes (XAG  XAG  XAG)
        $serial_data =~ s/^X//;
        my $serial_chunk;
        while ($serial_data) {
            if ($serial_data =~ /^([A-P]STATUS)(\S*)/ or
                $serial_data =~ /^([A-P]PRESET_DIM1)(\S*)/ or
                $serial_data =~ /^([A-P]PRESET_DIM2)(\S*)/ or
                $serial_data =~ /^([A-P][1-9A-W])(\S*)/ or
                $serial_data =~ /^([A-P]\&P\d+)(\S*)/ or 
                $serial_data =~ /^([A-P]\d+\%)(\S*)/ or 
                $serial_data =~ /^([A-P][\+\-]?\d+)(\S*)/) {
                $serial_chunk = $1;
                $serial_data  = $2;
                &send_x10_data($self, 'X' . $serial_chunk, $interface);
            }
            else {
                print "Serial_Item error, X10 string not parsed: $serial_data.\n";
                return;
            }
        }
        return;
    }

                                # Now deal with all other Serial strings
    elsif ($interface eq 'homevision') {
        print "Using homevision to send: $serial_data\n";
        &Homevision::send($main::Serial_Ports{Homevision}{object}, $serial_data);
    }
    elsif ($interface eq 'ncpuxa' or $port_name eq 'ncpuxa') {
        print "Using ncpuxa to send: $serial_data\n";
        &ncpuxa_mh::send($main::config_parms{ncpuxa_port}, $serial_data);
    }
    else {
                                # Pick a default port, if not specified
        $port_name = 'Homevision' if !$port_name and $main::Serial_Ports{Homevision}{object}; #Since it's multifunction, it should be default
        $port_name = 'weeder'  if !$port_name and $main::Serial_Ports{weeder}{object};
        $port_name = 'serial1' if !$port_name and $main::Serial_Ports{serial1}{object};
        $port_name = 'serial2' if !$port_name and $main::Serial_Ports{serial2}{object};
#       print "\$port_name is $port_name\n\$main::Serial_Ports{Homevision}{object} is $main::Serial_Ports{Homevision}{object}\n";
        unless ($port_name) {
            print "Error, serial set called, but no serial port found: data=$serial_data\n";
            return;
        }
        unless ($main::Serial_Ports{$port_name}{object}) {
            print "Error, serial port for $port_name has not been set: data=$serial_data\n";
            return;
        }

        if (lc($port_name) eq 'homevision') {
            &Homevision::send($main::Serial_Ports{Homevision}{object}, $serial_data);
        }
        else {
            my $datatype  = $main::Serial_Ports{$port_name}{datatype};
            $serial_data .= "\r" unless $datatype and $datatype eq 'raw';
            my $results = $main::Serial_Ports{$port_name}{object}->write($serial_data);
            
#           &main::print_log("serial port=$port_name out=$serial_data results=$results") if $main::config_parms{debug} eq 'serial';
            print "serial port=$port_name out=$serial_data results=$results\n" if $main::config_parms{debug} eq 'serial';
        }
    }

                                # Check for X10 All-on All-off house codes
                                #  - If found, set states of all X10_Items on that housecode
    if ($serial_data =~ /^X(\S)([OP])$/) {
        print "db l=$main::Loop_Count X10: mh set House code $1 set to $2\n" if $main::config_parms{debug} eq 'X10';
        my $state = ($2 eq 'O') ? 'on' : 'off';
        &X10_Item::set_by_housecode($1, $state);
    }
                                # Check for other items with the same codes
                                #  - If found, set them to the same state
    if ($serial_items_by_id{$serial_id} and my @refs = @{$serial_items_by_id{$serial_id}}) {
        for my $ref (@refs) {
            next if $ref eq $self;
                                # Only compare between items on the same port
            my $port_name1 = ($self->{port_name} or ' ');
            my $port_name2 = ($ref ->{port_name} or ' ');
            next unless $port_name1 eq $port_name2;

            print "Serial_Item: Setting duplicate state: id=$serial_id item1=$$self{object_name} item2=$$ref{object_name}\n" 
                if $main::config_parms{debug} eq 'serial';
            if ($state = $$ref{state_by_id}{$serial_id}) {
                $ref->set_receive($state);
            }
            else {
                $ref->set_receive($serial_id);
            }
        }
    }

}    

my $x10_save_unit;
sub send_x10_data {
    my ($self, $serial_data, $interface) = @_;
    my ($isfunc);

                                # Use proxy mh if present (avoids mh pauses for slow X10 xmits)
    return if &main::proxy_send($interface, 'send_x10_data', $serial_data, $interface);

    if ($serial_data =~ /^X[A-P][1-9A-G]$/) {
        $isfunc = 0;
        $x10_save_unit = $serial_data;
    }
    else {
        $isfunc = 1;
    }
    print "X10: interface=$interface isfunc=$isfunc save_unit=$x10_save_unit data=$serial_data\n" if $main::config_parms{debug} eq 'X10';

    if ($interface eq 'cm11') {
                                # cm11 wants individual codes without X
        &ControlX10::CM11::send($main::Serial_Ports{cm11}{object},
                                substr($serial_data, 1));
    }
    elsif ($interface eq 'lynx10plc') 
    {
	# marrick PLC wants XA1K
        &Lynx10PLC::send_plc($main::Serial_Ports{Lynx10PLC}{object},
			     "X" . substr($x10_save_unit, 1) . 
			     substr($serial_data, 2)) if $isfunc;
    }
    elsif ($interface eq 'cm17') {
                                # cm17 wants A1K, not XA1AK
        &ControlX10::CM17::send($main::Serial_Ports{cm17}{object},
                                substr($x10_save_unit, 1) . substr($serial_data, 2)) if $isfunc;
    }
    elsif ($interface eq 'homevision') {
                                # homevision wants XA1AK
        if ($isfunc) {
            print "Using homevision to send: " .
                $x10_save_unit . substr($serial_data, 1) . "\n";
            &Homevision::send($main::Serial_Ports{Homevision}{object},
                              $x10_save_unit . substr($serial_data, 1));
        }
    }
    elsif ($interface eq 'homebase') {
                                # homebase wants individual codes without X
        print "Using homebase to send: $serial_data\n";
        &HomeBase::send_X10($main::Serial_Ports{HomeBase}{object}, substr($serial_data, 1));
    }
    elsif ($interface eq 'stargate') {
                                # Stargate wants individual codes without X
        print "Using stargate to send: $serial_data\n";
        &Stargate::send_X10($main::Serial_Ports{Stargate}{object}, substr($serial_data, 1));
    }
    elsif ($interface eq 'houselinc') {
                                # houselinc wants XA1AK
        if ($isfunc) {
            print "Using houselinc to send: " .
                $x10_save_unit . substr($serial_data, 1) . "\n";
            &HouseLinc::send_X10($main::Serial_Ports{HouseLinc}{object},
                                 $x10_save_unit . substr($serial_data, 1));
        }
    }
    elsif ($interface eq 'marrick') {
                                # marrick wants XA1AK
        if ($isfunc) {
            print "Using marrick to send: " .
                $x10_save_unit . substr($serial_data, 1) . "\n";
            &Marrick::send_X10($main::Serial_Ports{Marrick}{object},
                               $x10_save_unit . substr($serial_data, 1));
        }
    }
    elsif ($interface eq 'ncpuxa') {
                                # ncpuxa wants individual codes with X
        print "Using ncpuxa to send: $serial_data\n";
        &ncpuxa_mh::send($main::config_parms{ncpuxa_port}, $serial_data);
    }
    elsif ($interface eq 'weeder') {
                                # Weeder table does not match what we defined in CM11,CM17,X10_Items.pm
                                #  - Dim -> L, Bright -> M,  AllOn -> I, AllOff -> H
        my ($device, $house, $command) = $serial_data =~ /^X(\S\S)(\S)(\S+)/;

                                # Allow for +-xx%
        my $dim_amount = 3;
        if ($command =~ /[\+\-]\d+/) {
            $dim_amount = int(10 * abs($command) / 100); # about 10 levels to 100%
            $command = ($command > 0) ? 'L' : 'M';
        }
        if ($command eq 'M') {
            $command =  'L' . (($house . 'L') x $dim_amount);
        }
        elsif ($command eq 'L') {
            $command =  'M' . (($house . 'M') x $dim_amount);
        }
        elsif ($command eq 'O') {
            $command =  'I';
        }
        elsif ($command eq 'P') {
            $command =  'H';
        }
        $serial_data = 'X' . $device . $house . $command;

        $main::Serial_Ports{weeder}{object}->write($serial_data);

				# Give weeder a chance to do the previous command
				# Surely there must be a better way!
        select undef, undef, undef, 1.2;
    }

    else {
        print "\nError, X10 interface not found: interface=$interface, data=$serial_data\n";
    }
}

sub set_interface {
    my ($self, $interface) = @_;
                                # Set the default interface
    unless ($interface) {
        if ($main::Serial_Ports{cm11}{object}) {
            $interface = 'cm11';
        }
        elsif ($main::Serial_Ports{Homevision}{object}) {
            $interface = 'homevision';
        }
        elsif ($main::Serial_Ports{HomeBase}{object}) {
            $interface = 'homebase';
        }
        elsif ($main::Serial_Ports{Stargate}{object}) {
            $interface = 'stargate';
        }
        elsif ($main::Serial_Ports{HouseLinc}{object}) {
            $interface = 'houselinc';
        }
        elsif ($main::Serial_Ports{Marrick}{object}) {
            $interface = 'marrick';
        }
        elsif ($main::config_parms{ncpuxa_port}) {
            $interface = 'ncpuxa';
        }
        elsif ($main::Serial_Ports{cm17}{object}) {
            $interface = 'cm17';
        }
        elsif ($main::Serial_Ports{weeder}{object}) {
            $interface = 'weeder';
        }
	elsif ($main::Serial_Ports{Lynx10PLC}{object}) {
            $interface = 'lynx10plc';
        }

    }
    $$self{interface} = lc($interface) if $interface;
}


#
# $Log$
# Revision 1.54  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.53  2002/01/19 21:11:12  winter
# - 2.63 release
#
# Revision 1.52  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.51  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.50  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.49  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.48  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.47  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.46  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.45  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.44  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.43  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.42  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.41  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.40  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.39  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.38  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.37  2000/05/27 16:40:10  winter
# - 2.20 release
#
# Revision 1.36  2000/05/06 16:34:32  winter
# - 2.15 release
#
# Revision 1.35  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.34  2000/02/13 03:57:27  winter
#  - 2.00 release.  New web server interface
#
# Revision 1.33  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.32  2000/01/27 13:42:42  winter
# - update version number
#
# Revision 1.31  2000/01/19 13:23:29  winter
# - add yucky delay to Weeder X10 xmit
#
# Revision 1.30  2000/01/02 23:47:43  winter
# - add Device:: to as Serilport check.  Use 10, not 7, increments in weeder dim
#
# Revision 1.29  1999/12/09 03:00:21  winter
# - added Weeder bright/dim support
#
# Revision 1.28  1999/11/08 02:16:17  winter
# - Move X10 stuff to X10_Items.pm.  Fix close method
#
# Revision 1.27  1999/11/02 14:51:36  winter
# - delete port in any case in stop method
#
# Revision 1.26  1999/10/31 14:49:04  winter
# - added X10 &P## preset dim option and X10_Lamp item
#
# Revision 1.25  1999/10/27 12:42:27  winter
# - add delete to serial_ports_by_port in sub close
#
# Revision 1.24  1999/10/09 20:36:49  winter
# - add call to set_interface in first new method.  Change to ControlX10
#
# Revision 1.23  1999/10/02 22:41:10  winter
# - move interface stuff to set_interface, so we can use for x10_appliances also
#
# Revision 1.22  1999/09/27 03:16:32  winter
# - move cm11 to HomeAutomation dir
#
# Revision 1.21  1999/09/12 16:57:07  winter
# - point to new cm17 path
#
# Revision 1.20  1999/08/30 00:23:30  winter
# - add set_dtr set_rts.  Add check on loop_count
#
# Revision 1.19  1999/08/02 02:24:21  winter
# - Add STATUS state
#
# Revision 1.18  1999/06/27 20:12:09  winter
# - add CM17 support
#
# Revision 1.17  1999/06/20 22:32:43  winter
# - check for raw datatype on writes
#
# Revision 1.16  1999/04/29 12:25:20  winter
# - add House all on/off states
#
# Revision 1.15  1999/03/21 17:35:36  winter
# - add datatype raw
#
# Revision 1.14  1999/03/12 04:30:24  winter
# - add start, stop, and set_receive methods
#
# Revision 1.13  1999/02/16 02:06:57  winter
# - add homebase send errata
#
# Revision 1.12  1999/02/08 03:50:25  winter
# - re-enable serial writes!  Bug introduced in last install.
#
# Revision 1.11  1999/02/08 00:30:54  winter
# - make serial port prints depend on debug parm
#
# Revision 1.10  1999/01/30 19:55:45  winter
# - add more checks for blank objects, so we don't abend
#
# Revision 1.9  1999/01/23 16:23:43  winter
# - change the Serial_Port object to match Socket_Port format
#
# Revision 1.8  1999/01/13 14:11:03  winter
# - add some more debug records
#
# Revision 1.7  1999/01/07 01:55:40  winter
# - add 5% increments on X10_Item
#
# Revision 1.6  1998/12/10 14:34:19  winter
# - fix empty state case
#
# Revision 1.5  1998/12/07 14:33:27  winter
# - add dim level support.  Allow for arbitrary set commands.
#
# Revision 1.4  1998/11/15 22:04:26  winter
# - add support for generic serial ports
#
# Revision 1.3  1998/09/12 22:13:14  winter
# - added HomeBase call
#
# Revision 1.2  1998/08/29 20:46:36  winter
# - allow for cm11 interface
#
#

1;