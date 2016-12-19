#!/usr/bin/perl
### BEGIN INIT INFO
# Provides:          zenloadbalancer
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: zenloadbalancer
# Description:
#
### END INIT INFO

###############################################################################
#
#     Zen Load Balancer Software License
#     This file is part of the Zen Load Balancer software package.
#
#     Copyright (C) 2014 SOFINTEL IT ENGINEERING SL, Sevilla (Spain)
#
#     This library is free software; you can redistribute it and/or modify it
#     under the terms of the GNU Lesser General Public License as published
#     by the Free Software Foundation; either version 2.1 of the License, or
#     (at your option) any later version.
#
#     This library is distributed in the hope that it will be useful, but
#     WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
#     General Public License for more details.
#
#     You should have received a copy of the GNU Lesser General Public License
#     along with this library; if not, write to the Free Software Foundation,
#     Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
###############################################################################

sub configureDefaultGW()
{
	print "\n";
	if ( $ARGV[0] =~ /^start.*/ )
	{
		chomp ( $defaultgwif );
		if ( $defaultgw ne "" && $defaultgwif ne "" )
		{
			print "Default Gateway:$defaultgw Device:$defaultgwif\n";
			&applyRoutes( "global", $defaultgwif, $defaultgw );
		}
	}
}

sub runhttpsgui()
{
	#print "Running HTTPS GUI";
	if ( $pid = fork )
	{
		#$SIG{'CHLD'}='IGNORE';
	}
	elsif ( defined $pid )
	{
		system ( "/usr/sbin/mini_httpd -C $confhttp > /dev/null &" );
		exit ( 0 );
	}
}

#endfunction
$globalcfg = "/usr/local/zenloadbalancer/config/global.conf";
$limitfile = "/etc/security/limits.conf";
require ( $globalcfg );
require ( "/usr/local/zenloadbalancer/www/functions.cgi" );
require ( "/usr/local/zenloadbalancer/www/cluster_functions.cgi" );

$eject = $ARGV[0];
use Tie::File;
use Sys::Hostname;

if ( !$eject && $eject !~ /stop|start|status|startlocal|stoplocal/ )
{
	print "Usage: /etc/init.d/zenloadbalancer stop|start|status|startlocal|stoplocal\n";
	exit;
}

if ( $eject eq "restart" )
{
	my @eject = `/etc/init.d/zenloadbalancer stop`;
	my @eject = `/etc/init.d/zenloadbalancer start`;
}

if ( $eject eq "start" )
{
	system ( "/usr/local/zenloadbalancer/app/checkglobalconf/checkglobalconf.cgi" );

	# Set system tuning.
	$sysctl = "/etc/sysctl.conf";
	use Tie::File;
	tie @filelines, 'Tie::File', "$sysctl";
	@filelines = grep !/^net\.ipv4\.tcp_tw_recycle/, @filelines;
	if ( !grep ( /^fs\.file-max/, @filelines ) )
	{
		push ( @filelines, "fs.file-max = 100000" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_max_tw_buckets/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_max_tw_buckets = 100000" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_low_latency/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_low_latency = 1" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_tw_reuse/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_tw_reuse = 1" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_tw_recycle/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_tw_recycle = 0" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_keepalive_time/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_keepalive_time = 512" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_fin_timeout/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_fin_timeout = 5" );
	}
	if ( !grep ( /^net\.ipv4\.inet_peer_maxttl/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.inet_peer_maxttl = 5" );
	}
	if ( !grep ( /^net\.core\.rmem_max/, @filelines ) )
	{
		push ( @filelines, "net.core.rmem_max = 262143" );
	}
	if ( !grep ( /^net\.core\.rmem_default/, @filelines ) )
	{
		push ( @filelines, "net.core.rmem_default = 262143" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_keepalive_intvl/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_keepalive_intvl = 15" );
	}
	if ( !grep ( /^net\.core\.netdev_max_backlog/, @filelines ) )
	{
		push ( @filelines, "net.core.netdev_max_backlog = 3000" );
	}
	if ( !grep ( /^net\.core\.somaxconn/, @filelines ) )
	{
		push ( @filelines, "net.core.somaxconn = 3000" );
	}
	if ( !grep ( /^net\.ipv4\.tcp_keepalive_probes/, @filelines ) )
	{
		push ( @filelines, "net.ipv4.tcp_keepalive_probes = 5" );
	}
	untie @filelines;

	$status = `sysctl -p > /dev/null`;

	if ( -e $filecluster )
	{
		print "Cluster file exist\n";
		$host = hostname();

		#get cluster's members data

		#get cluster's type and status
		@cltypestatus = &getClusterTypeStatus( $filecluster );
		$typecl       = @cltypestatus[0];
		$clstatus     = @cltypestatus[1];

		if ( $clstatus =~ /UP/ )
		{
			print "UP status configured\n";

			@clmembers = &getClusterMembersData( $host, $filecluster );
			$lhost     = @clmembers[0];
			$lip       = @clmembers[1];
			$rhost     = @clmembers[2];
			$rip       = @clmembers[3];

			#get cluster's VIP data
			@clvipdata = &getClusterVIPData( $filecluster );
			$vipcl     = @clvipdata[0];
			$ifclname  = @clvipdata[1];

			#get cluster's cable link data
			$cable     = &getClusterCableLink( $filecluster );
			@rifclname = split ( ":", $ifclname );
			@cliface   = ( "IPCLUSTER", $vipcl, $rifclname[0], $rifclname[1] );
			$cltype    = "TYPECLUSTER:$typecl:$clstatus";

			#get cluster's ID
			$idcluster = &getClusterID( $filecluster );
			print "Cluster ID: $idcluster";

			#get cluster DEADRATIO
			$deadratio = &getClusterDEADRATIO( $filecluster );
			print "Cluster Deadratio:$deadratio";

			print "Host:$host CL_LIP:$lip CL_RIP:$rip CL_IF:@cliface[2] CL_IP:@cliface[1]\n";

			#if real interface not configured, configured it
			&createIf( @cliface[2] );
			&upIf( @cliface[2] );
			open FO, "<$configdir\/if\_@cliface[2]\_conf";
			@fileif = <FO>;
			chomp ( @fileif[0] );
			@netmask = split ( ":", @fileif[0] );
			my $run = `$ifconfig_bin @cliface[2] $lip netmask @netmask[3]`;

			$ifgw   = @cliface[2];
			$ipifgw = &gwofif( $ifgw );
			&writeRoutes( $ifgw );
			&applyRoutes( "local", @cliface[2], $ipifgw );

			if ( $cable eq "Crossover cord" )
			{
				$ignoreifstate = "--ignoreifstate";
			}
			else
			{
				$ignoreifstate = "";
			}

			if ( $cltype =~ /^equal$/ )
			{
				print "CL_TYPE=equal\n";
				my @eject = system (
					"$ucarp $ignoreifstate -r $deadratio --interface=@cliface[2] --srcip=$lip --vhid=$idcluster --pass=secret --addr=@cliface[1] --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6"
				);
			}
			elsif ( $cltype =~ /$lhost-$rhost/ )
			{
				print "CL_TYPE=M-B, Master node\n";
				my @eject = system (
					"$ucarp $ignoreifstate -r $deadratio --interface=@cliface[2] --srcip=$lip -P --vhid=$idcluster --pass=secret --addr=@cliface[1] --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6"
				);
			}
			else
			{
				print "CL_TYPE=M-B Backup node\n";
				my @eject = system (
					"$ucarp $ignoreifstate -r $deadratio --interface=@cliface[2] -k 50 --srcip=$lip --vhid=$idcluster --pass=secret --addr=@cliface[1] --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6"
				);
			}
			chomp ( $lip );

			#check the gui interface
			print "Running GUI interface\n";
			$filehttp = "";
			open FH, "<$confhttp";
			@filehttp = <FH>;
			$host     = @filehttp[0];
			@host     = split ( "=", $host );
			$iphttp   = @host[1];
			close FH;

			if ( $lip ne $iphttp )
			{
				opendir ( DIR, $configdir );
				@files = grep ( /^if\_.*\_conf$/, readdir ( DIR ) );
				closedir ( DIR );
				foreach $file ( @files )
				{
					if ( $file !~ /:/ )
					{
						open FR, "<$configdir\/$file";
						@fif = <FR>;
						close FR;
						chomp ( $iphttp );
						if ( $iphttp !~ /\*/ && ( grep ( /$iphttp/, @fif ) ) )
						{
							$filehttp = $file;
						}
					}
				}
				open FGUI, "<$configdir/$filehttp";
				$filehttp = <FGUI>;
				my @lastline = split ( ":", $filehttp );
				if ( @lastline[4] eq "up" )
				{
					print "HTTPS GUI Interface:@lastline[0] Ip:@lastline[2] Netmask:@lastline[3]";
					if ( @lastline[5] ne '' )
					{
						" Gateway:@lastline[5]";
					}
					my $run = `$ifconfig_bin @lastline[0] @lastline[2] netmask @lastline[3]`;
					$ok = $?;
					chomp ( @lastline[5] );
					&applyRoutes( "local", @lastline[0], @lastline[5] );
					&upIf( @lastline[0] );
					if ( $ok == 0 )
					{
						print " \033[1;32m OK \033[0m \n";
					}
					else
					{
						print " \033[1;31m ERROR \033[0m \n";
					}
				}
				close FGUI;
			}

			sleep ( 5 );

			#check if virtual interface cluster is up:
			my @eject = `$ifconfig_bin`;
			print "CL_IP: @cliface[1]\n";
			if ( grep ( /@cliface[1]/, @eject ) )
			{
				print
				  "Cluster is running on this node, running IPS and FARMS for Zen Load Balancer...\n";
				$eject = "startlocal";
			}
		}
		else
		{
			$eject = "startlocal";
		}
	}
	else
	{
		$eject = "startlocal";
	}
}

if ( $eject eq "stop" )
{
	if ( -e $filecluster )
	{
		open FO, "<$filecluster";
		@file = <FO>;
		close FO;
		if ( grep ( /UP/, @file ) )
		{
			my @eject = `pkill -9 ucarp`;
			my @eject = `pkill -9f zeninotify.pl`;
			print "Stopping Zen Cluster on this node...\n";
		}

	}
	sleep ( 5 );
	$eject = "stoplocal";
}

if ( $eject eq "startlocal" )
{
	$rsyslog = "/etc/rsyslog.conf";
	open FR, "<$rsyslog";
	my @filelog = <FR>;
	close FR;
	if ( !grep ( /ucarp/, @filelog ) )
	{
		my @eject = `echo \"local6.* /usr/local/zenloadbalancer/logs/ucarp.log\">> $rsyslog`;
		my @eject = `/etc/init.d/rsyslog restart`;
	}

	#check if repository is configured
	open FR, "</etc/apt/sources.list";
	my @repo = <FR>;
	close FR;

	#testing interface configured on the installation and gw
	if ( -e "/etc/network/interfaces" )
	{
		open FR, "/etc/network/interfaces";
		@file = <FR>;
		close FR;
		if ( !grep ( /zenmodified/, @file ) )
		{
			foreach $line ( @file )
			{
				chomp ( $line );
				if ( $line =~ /iface.*inet static/i )
				{
					@iface = split ( " ", $line );
					$ifname = @iface[1];
					chomp ( $ifname );
				}
				if ( $line =~ /address/i )
				{
					@ip = split ( " ", $line );
					$ip = @ip[1];
					chomp ( $ip );
				}
				if ( $line =~ /netmask/i )
				{
					@netmask = split ( " ", $line );
					$netmask = @netmask[1];
					chomp ( $netmask );
				}
				if ( $line =~ /gateway/i )
				{
					@gateway = split ( " ", $line );
					$gateway = @gateway[1];
					chomp ( $gateway );
				}
			}

			#deleting interfaces file
			open FW, ">/etc/network/interfaces";
			print FW "#zenmodified\n";
			print FW "auto lo\n";
			print FW "iface lo inet loopback\n";
			close FW;

			#creating configuration interface file:
			open FW, ">$configdir\/if\_$ifname\_conf";
			print FW "$ifname\:\:$ip\:$netmask\:up\:\:\n";
			close FW;

			#gw
			tie @contents, 'Tie::File', "$globalcfg";
			for ( @contents )
			{
				if ( grep /^\$defaultgw/, $_ )
				{
					s/^\$defaultgw=.*/\$defaultgw=\"$gateway\"\;/g;
					s/^\$defaultgwif=.*/\$defaultgwif=\"$ifname\"\;/g;
				}
			}
			untie @contents;

			#routes
			open FW, ">>/etc/iproute2/rt_tables";
			print FW "200\ttable_$ifname\n";
			close FW;
		}
	}

	### Starting Network Interfaces
	print "Starting Zen Load Balancer...\n";
	opendir ( DIR, $configdir );
	@files = grep ( /^if\_.*\_conf$/, readdir ( DIR ) );
	closedir ( DIR );
	print "* Starting Interfaces:\n";

	#first real interfaces
	foreach $file ( @files )
	{
		#interfaces as eth0 for example
		if ( $file !~ /:/ && $file !~ /\./ )
		{
			my @file_s = split ( "\_", $file );
			print "  * Starting interface @file_s[1]\n";
			open FR, "$configdir/$file";
			while ( $line = <FR> )
			{
				$lastline = $line;
			}
			close FR;
			my @lastline = split ( ":", $lastline );
			if ( @lastline[4] eq "up" )
			{
				print "    Interface:@lastline[0] Ip:@lastline[2] Netmask:@lastline[3]";
				if ( @lastline[5] ne '' )
				{
					" Gateway:@lastline[5]";
				}
				my $run = `$ifconfig_bin @lastline[0] @lastline[2] netmask @lastline[3]`;
				$ok = $?;
				chomp ( @lastline[5] );
				&writeRoutes( @lastline[0] );
				&applyRoutes( "local", @lastline[0], @lastline[5] );
				&upIf( @lastline[0] );
				if ( $ok == 0 )
				{
					print " \033[1;32m OK \033[0m \n";
				}
				else
				{
					print " \033[1;31m ERROR \033[0m \n";
				}
			}
			&sendGArp( @lastline[0], @lastline[2] );
		}
	}

	#intrfaces as eth0.20 for example
	foreach $file ( @files )
	{
		if ( $file =~ /\./ && $file !~ /:/ )
		{
			my @file_s = split ( "\_", $file );
			print "  * Starting interface @file_s[1]\n";
			open FR, "$configdir/$file";
			while ( $line = <FR> )
			{
				$lastline = $line;
			}
			close FR;
			my @lastline = split ( ":", $lastline );
			if ( @lastline[4] eq "up" )
			{
				print "    Interface:@lastline[0] Ip:@lastline[2] Netmask:@lastline[3]";
				if ( @lastline[5] ne '' )
				{
					" Gateway:@lastline[5]";
				}
				&createIf( @lastline[0] );
				&upIf( @lastline[0] );
				my $run = `$ifconfig_bin @lastline[0] @lastline[2] netmask @lastline[3]`;
				$ok = $?;
				if ( $ok == 0 )
				{
					print " \033[1;32m OK \033[0m \n";
				}
				else
				{
					print " \033[1;31m ERROR \033[0m \n";
				}
				chomp ( @lastline[5] );
				&writeRoutes( @lastline[0] );
				&applyRoutes( "local", @lastline[0], @lastline[5] );
				&sendGArp( @lastline[0], @lastline[2] );
			}
		}
	}

	#intrfaces as eth0:20 || eth0.20:2 for example
	foreach $file ( @files )
	{
		if ( $file =~ /:/ )
		{
			my @file_s = split ( "\_", $file );
			print "  * Starting interface @file_s[1]\n";
			open FR, "$configdir/$file";
			while ( $line = <FR> )
			{
				$lastline = $line;
			}
			close FR;
			my @lastline = split ( ":", $lastline );
			if ( @lastline[4] eq "up" )
			{
				print
				  "    Interface:@lastline[0]:@lastline[1] Ip:@lastline[2] Netmask:@lastline[3]";
				@iface = split ( /\./, @lastline[0] );
				&upIf( "@lastline[0]:@lastline[1]" );
				my $run =
				  `$ifconfig_bin @lastline[0]\:@lastline[1] @lastline[2] netmask @lastline[3]`;
				$ok = $?;
				&applyRoutes( "local", "@lastline[0]:@lastline[1]", "" );
				if ( $ok == 0 )
				{
					print " \033[1;32m OK \033[0m \n";
				}
				else
				{
					print " \033[1;31m ERROR \033[0m \n";
				}
			}
			&sendGArp( @lastline[0], @lastline[2] );
		}
	}

	### Starting Farms
	print "* Starting Farms:\n";
	@farmsf = &getFarmList();
	foreach $ffile ( @farmsf )
	{
		$farmname = &getFarmName( $ffile );
		$bstatus  = &getFarmBootStatus( $farmname );
		if ( $bstatus eq "up" )
		{
			print "  * Starting Farm $farmname:";
			$status = &_runFarmStart( $farmname, "false" );
			if ( $status == 0 )
			{
				print " \033[1;32m OK \033[0m \n";
			}
			else
			{
				print " \033[1;31m ERROR \033[0m \n";
			}

			#farmguardian configured and up?
			$fgstatus = &getFarmGuardianStatus( $farmname );
			if ( ( $status == 0 ) && ( $fgstatus == 1 ) )
			{
				print "  * Starting Farm Guardian for $farmname:";
				$stat = &runFarmGuardianStart( $farmname, "" );
				if ( $stat == 0 )
				{
					print " \033[1;32m OK \033[0m \n";
				}
				else
				{
					print " \033[1;31m ERROR \033[0m \n";
				}
			}
		}
		else
		{
			print "  Farm $farmname configured DOWN\n";
		}
	}

	#At this point every zen interfaces and farms are running
	#now a personalized script can be executed

	my @ownscript = `$configdir/zlb-start`;
	print "@ownscript";

}

if ( $eject eq "stoplocal" )
{
	print "Stopping Zen Load Balancer...\n";

	### Stopping Farms
	print "* Stopping Farms:\n";

	@farmsf = &getFarmList();
	foreach $ffile ( @farmsf )
	{
		$farmname = &getFarmName( $ffile );
		$status   = &getFarmStatus( $farmname );
		if ( $status eq "up" )
		{
			#farmguardian configured and up?
			$fgstatus = &getFarmGuardianPid( $farmname );
			if ( $fgstatus != -1 )
			{
				print "  * Stopping Farm Guardian for $farmname:";
				$stat = &runFarmGuardianStop( $farmname, "" );
				if ( $stat == 0 )
				{
					print " \033[1;32m OK \033[0m \n";
				}
				else
				{
					print " \033[1;31m ERROR \033[0m \n";
				}
			}
			print "  * Stopping Farm $farmname:";
			$status = &_runFarmStop( $farmname, "false" );
			if ( $status == 0 )
			{
				print " \033[1;32m OK \033[0m \n";
			}
			else
			{
				print " \033[1;31m ERROR \033[0m \n";
			}
		}
	}

	### Stopping Network Interfaces
	opendir ( DIR, $configdir );
	@files = grep ( /^if\_.*\_conf$/, readdir ( DIR ) );
	closedir ( DIR );
	print "* Stopping Interfaces:\n";
	foreach $file ( @files )
	{
		if ( $file =~ /:/ )
		{
			my @file_s = split ( "\_", $file );
			print "  * Down interface @file_s[1]\n";
			open FR, "$configdir/$file";
			while ( $line = <FR> )
			{
				$lastline = $line;
			}
			close FR;
			my @lastline = split ( ":", $lastline );
			print "    Interface:@lastline[0]:@lastline[1] Ip:@lastline[2] Netmask:@lastline[3]";

			&delRoutes( "local", "@lastline[0]:@lastline[1]" );
			&downIf( "@lastline[0]:@lastline[1]" );
			if ( $? == 0 )
			{
				print " \033[1;32m OK \033[0m \n";
			}
			else
			{
				print " \033[1;31m ERROR \033[0m \n";
			}
		}
	}

	foreach $file ( @files )
	{
		if ( $file !~ /:/ )
		{
			my @file_s = split ( "\_", $file );
			print "  * Down interface @file_s[1]\n";
			open FR, "$configdir/$file";
			while ( $line = <FR> )
			{
				$lastline = $line;
			}
			close FR;
			my @lastline = split ( ":", $lastline );
			print "    Interface:@lastline[0] Ip:@lastline[2] Netmask:@lastline[3]";

			if ( -e $filecluster )
			{
				$gui = &GUIip();
				open FO, "<$filecluster";
				@filecl = <FO>;
				close FO;
				if ( !grep ( /@lastline[0]/, @filecl ) && $gui ne @lastline[2] )
				{
					&delRoutes( "local", @lastline[0] );
					&downIf( @lastline[0] );
					if ( $? == 0 )
					{
						print " \033[1;32m OK \033[0m \n";
					}
					else
					{
						print " \033[1;31m ERROR \033[0m \n";
					}

				}
			}
			else
			{
				$gui = &GUIip();
				if ( $gui ne @lastline[2] )
				{
					&delRoutes( "local", @lastline[0] );
					&downIf( @lastline[0] );
					if ( $? == 0 )
					{
						print " \033[1;32m OK \033[0m \n";
					}
					else
					{
						print " \033[1;31m ERROR \033[0m \n";
					}
				}
				else
				{
					print "  no DOWN, it is the Zen GUI\n";
				}

			}
		}
	}

	#At this point every zen interfaces and farms are stopped
	#now a personalized script can be executed

	my @ownscript = `$configdir/zlb-stop`;
	print "@ownscript";

}
&runhttpsgui();
&configureDefaultGW();
