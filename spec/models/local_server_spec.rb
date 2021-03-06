require 'spec_helper'

describe LocalServer do

  it { should validate_presence_of(:path) }
  it { should validate_presence_of(:ip) }
  it { should validate_presence_of(:port) }
  it { should validate_presence_of(:name) }

  describe '.with_group' do

    it 'should find servers in a group' do
      group       = create :group, :name => "Great group"
      other_group = create :group, :name => "Other group"
      server_in_group     = create :server, :groups => [group], :name => "server in group"
      server_not_in_group = create :server, :name => "server in no groups"
      server_other_group  = create :server, :groups => [other_group], :name => "server other group"

      Server.with_group.should =~ [server_in_group, server_other_group]
    end

  end

  describe '.active' do

    it 'returns active servers' do
      active_server   = create :server, :name => "Active"
      inactive_server = create :server, :name => "Inactive", :active => false
      Server.active.should == [active_server]
    end
  end

  describe '.in_groups' do

    it 'should find servers belonging to a certain group' do
      group       = create :group, :name => "Great group"
      other_group = create :group, :name => "Other group"
      server_in_group     = create :server, :groups => [group], :name => "server in group"
      server_not_in_group = create :server, :name => "server in no groups"
      server_other_group  = create :server, :name => "server other group", :groups => [other_group]

      Server.in_groups([group]).should eq [server_in_group]
    end

    it 'should only return servers once even with multiple matching groups' do
      group       = create :group, :name => "Great group"
      group2      = create :group, :name => "Great group 2"
      other_group = create :group, :name => "Other group"
      server_in_group     = create :server, :groups => [group, group2], :name => "server in group"
      server_not_in_group = create :server, :name => "server in no groups"
      server_other_group  = create :server, :name => "server other group", :groups => [other_group]

      Server.in_groups([group, group2]).should eq [server_in_group]
    end

  end

  describe '.ordered' do

    it "orders by position and name" do
      fourth  = create :server, :position => 3, :name => "AB"
      second  = create :server, :position => 1, :name => "A1"
      first   = create :server, :position => 1, :name => "A0"
      third   = create :server, :position => 2, :name => "B0"

      Server.ordered.should == [first, second, third, fourth]
    end
  end

  describe '.reservable_by_user' do

    it "returns servers in the users group and servers without groups regardless of reservations" do
      users_group                 = create :group,  :name => "User's group"
      other_group                 = create :group,  :name => "Not User's group"
      user                        = create :user,   :groups => [users_group]
      free_server_in_users_group  = create :server, :groups => [users_group], :name => "free server in user's group"
      busy_server_in_users_group  = create :server, :groups => [users_group], :name => "busy server in user's group"
      free_server_other_group     = create :server, :groups => [other_group], :name => "free server not in user's group"
      free_server_no_group        = create :server, :groups => []
      busy_server_no_group        = create :server, :groups => []
      create :reservation, :server => busy_server_in_users_group, :user => user
      create :reservation, :server => busy_server_no_group

      Server.reservable_by_user(user).should =~ [free_server_in_users_group, busy_server_in_users_group, free_server_no_group, busy_server_no_group]
    end

  end

  describe '#start_reservation' do
    it 'updates the configuration and triggers a restart' do
      reservation = stubbed_reservation(:enable_plugins? => true)
      subject.should_receive(:restart)
      subject.should_receive(:enable_plugins)
      subject.should_receive(:disable_arena_respawn)
      subject.should_receive(:update_configuration).with(reservation)
      subject.start_reservation(reservation)
    end

    it 'writes a config file' do
      reservation = stubbed_reservation(:custom_whitelist_id => nil)
      subject.should_receive(:restart)
      file = double
      subject.stub(:tf_dir => '/tmp')
      File.should_receive(:open).with(anything, 'w').twice.and_yield(file)
      file.should_receive(:write).with(anything).twice
      subject.should_receive(:generate_config_file).twice.with(reservation, anything).and_return("config file contents")
      subject.start_reservation(reservation)
    end

    context "with enable arena respawn enabled" do

      it "copies the arena respawn stuff and enables plugins" do
        reservation = stubbed_reservation(:enable_plugins? => true, :enable_arena_respawn? => true)
        subject.should_receive(:restart)
        subject.should_receive(:update_configuration).with(reservation)
        subject.should_receive(:enable_plugins)
        subject.should_receive(:enable_arena_respawn)
        subject.start_reservation(reservation)
      end
    end

  end

  describe '#end_reservation' do

    it 'should zip demos and logs, remove configuration and restart' do
      reservation = double(:rcon => "foo", :status_update => nil, :ended? => false)
      subject.should_receive(:copy_logs)
      subject.should_receive(:zip_demos_and_logs).with(reservation)
      subject.should_receive(:disable_plugins)
      subject.should_receive(:remove_logs_and_demos)
      subject.should_receive(:remove_configuration)
      subject.should_receive(:rcon_exec).twice
      subject.should_receive(:restart)
      subject.end_reservation(reservation)
    end

  end

  describe '#update_reservation' do

    it "should only update the configuration" do
      reservation = double
      subject.should_receive(:update_configuration)
      subject.update_reservation(reservation)
    end

  end

  describe '#restart' do

    it "sends the software termination signal to the process" do
      subject.should_receive(:process_id).at_least(:once).and_return(1337)
      Process.should_receive(:kill).with(15, 1337)
      subject.restart
    end

    it "logs an error when it couldn't find the process id" do
      logger = double
      subject.stub(:logger).and_return(logger)
      subject.should_receive(:process_id).at_least(:once).and_return(nil)
      Process.should_not_receive(:kill)

      logger.should_receive(:error)

      subject.restart
    end

  end

  describe '#find_process_id' do
    it 'picks the correct pid from the list' do
      correct_process = './srcds_linux -game tf -port 27015 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27020 +tv_maxclients 32 +tv_enable 1"'
      other_processes = ["/bin/sh ./srcds_run -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay relay.vanillatv.org:27100 +password +tv_autorecord 1",
                        "./srcds_linux -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay relay.vanillatv.org:27100 +password +tv_autorecord 1",
                        "SCREEN -AmdS tf2-4 ./srcds_run -game tf -port 27045 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27050 +tv_maxclients 32 +tv_enable 1 +exec server.cfg",
                        "/bin/sh ./srcds_run -game tf -port 27045 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27050 +tv_maxclients 32 +tv_enable 1 +exec server.cfg",
                        "SCREEN -AmdS webrelay ./srcds_run -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay 176.9.138.143:27030 +password tv +tv_autorecord 1",
                        "/bin/sh ./srcds_run -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay 176.9.138.143:27030 +password tv +tv_autorecord 1",
                        "./srcds_linux -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay 176.9.138.143:27030 +password tv +tv_autorecord 1",
                        "./srcds_linux -game tf -port 27025 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27030 +tv_maxclients 32 +tv_enable 1"]
      processes = []
      other_processes.each_with_index do |process, index|
        processes << double(:cmdline => process, :pid => 2000 + index)
      end
      processes << double(:cmdline => correct_process, :pid => 1337)
      Sys::ProcTable.should_receive(:ps).and_return(processes)

      subject.stub(:port => '27015')
      subject.process_id.should eql 1337
    end
  end

  describe '#tf_dir' do

    it "takes the server's path and adds the TF2 dirs" do
      subject.stub(:path => '/foo/bar')
      subject.tf_dir.should eql '/foo/bar/tf'
    end

  end

  describe '#current_reservation' do

    it 'returns nil if there is no reservation active on the server' do
      server = create(:server)
      server.current_reservation.should eql nil
    end

    it 'gives the current reservation if there is one' do
      server      = create(:server)
      reservation = create(:reservation, :starts_at => 1.minute.ago, :ends_at => 1.hour.from_now, :server => server)

      server.current_reservation.should eql reservation
    end

  end

  describe '#current_rcon' do

    it "gives the normal rcon if there's no reservation active" do
      subject.stub(:rcon => 'the rcon')
      subject.current_rcon.should eql 'the rcon'
    end

    it "gives the rcon of the current reservation if there is one" do
      subject.stub(:current_reservation => mock_model(Reservation, :rcon => 'foo', :provisioned? => true))
      subject.stub(:rcon => 'bar')
      subject.current_rcon.should eql 'foo'
    end

  end

  describe "#occupied?" do

    it "is occupied when there's more than 0 players" do
      ServerInfo.should_receive(:new).with(subject).and_return(double(:number_of_players => 1))
      subject.should be_occupied
    end

    it "defaults to true when something went wrong updating the player number" do
      ServerInfo.should_receive(:new).with(subject).and_raise(SteamCondenser::Error::Timeout)
      subject.should be_occupied
    end

  end

  describe "#remove_configuration" do

    before do
      @tf_dir       = Rails.root.join('tmp')
      @config_file  = @tf_dir.join('cfg', 'reservation.cfg').to_s
      @map_file     = @tf_dir.join('cfg', 'ctf_turbine.cfg').to_s
    end
    it 'deletes the reservation.cfg if its available' do
      subject.stub(:tf_dir => @tf_dir)

      File.should_receive(:exists?).with(@config_file).and_return(true)
      File.should_receive(:delete).with(@config_file)
      File.should_receive(:exists?).with(@map_file).and_return(true)
      File.should_receive(:delete).with(@map_file)
      subject.remove_configuration
    end

    it 'does not explode when there is no reservation.cfg' do
      subject.stub(:tf_dir => @tf_dir)

      File.should_receive(:exists?).with(@config_file).and_return(false)
      File.should_not_receive(:delete).with(@config_file)
      File.should_receive(:exists?).with(@map_file).and_return(false)
      File.should_not_receive(:delete).with(@map_file)
      subject.remove_configuration
    end
  end

  describe "#inactive_minutes" do

    it "shows the inactive minutes from the current reservation" do
      subject.stub(:current_reservation => double(:inactive_minute_counter => 10))
      subject.inactive_minutes.should eql 10
    end

    it "is 0 if there is no current reservation" do
      subject.stub(:current_reservation => nil)
      subject.inactive_minutes.should eql 0
    end

  end

  describe "#copy_to_server" do

    it "uses a simple local copy" do
      files = double(:files)
      destination = double(:destination)
      FileUtils.should_receive(:cp).with(files, destination)
      subject.copy_to_server(files, destination)
    end

  end

  describe "#list_files" do

    it "takes the globbed files and returns just the basename" do
      complete_filepaths = ["/foo/bar/baz.bsp", "/foo/bar/qux.txt"]
      subject.stub(:tf_dir => "foo")
      dir = "bar"
      Dir.should_receive(:glob).with(File.join(subject.tf_dir, dir, "*")).and_return(complete_filepaths)

      subject.list_files("bar").should == ['baz.bsp', 'qux.txt']
    end

  end

  describe '#remove_logs_and_demos' do

    it 'removes the logs and demos from disk' do
      subject.stub(:logs  => [double])
      subject.stub(:demos => [double])
      files = subject.logs + subject.demos
      FileUtils.should_receive(:rm).with(files)
      subject.remove_logs_and_demos
    end

  end

  describe '#condenser' do

    it 'creates a steam condenser to the server' do
      subject.stub(:ip => 'fakkelbrigade.eu', :port => "27015")
      SteamCondenser::Servers::SourceServer.should_receive(:new).with('fakkelbrigade.eu', 27015)
      subject.condenser
    end

  end

  describe '#rcon_auth' do

    it "sends the current rcon to the condenser" do
      condenser = double
      subject.stub(:condenser => condenser, :current_rcon => "foobar")
      condenser.should_receive(:rcon_auth).with("foobar")
      subject.rcon_auth
    end

  end

  describe '#rcon_say' do

    let(:message)       { "Hello world!" }
    let(:condenser)     { double }
    let(:current_rcon)  { double }

    before do
      subject.stub(:condenser => condenser, :current_rcon => current_rcon)
      condenser.should_receive(:rcon_auth).with(current_rcon).and_return(true)
    end

    it "delivers a message with rcon say to the server" do
      condenser.should_receive(:rcon_exec).with("say #{message}")
      subject.rcon_say(message)
    end

    it "logs an error if something went wrong" do
      condenser.should_receive(:rcon_exec).and_raise(SteamCondenser::Error::Timeout)
      logger = double
      Rails.stub(:logger => logger)
      logger.should_receive(:error).with(anything)
      subject.rcon_say "foobar"
    end
  end

  describe "#enable_plugins" do

    it "writes the metamod.vdf to the server" do
      subject.should_receive(:path).at_least(:once).and_return("foo")
      subject.should_receive(:write_configuration).with(subject.metamod_file, anything)
      subject.enable_plugins
    end
  end

  describe "#rating" do

    let(:server)      { create :server }
    let(:reservation) { create :reservation, :server => server }

    it "retuns a rating between 0.0 and 1.0" do
      server.rating.should == 1.0
      good_rating = create_rating("good")
      server.rating.should == 1.0
      bad_rating = create_rating("bad")
      server.rating.should == 0.5
      good_rating.destroy
      server.rating.should == 0.0
      bad_rating.destroy
      server.rating.should == 1.0
    end

    def create_rating(opinion)
      create(:rating, :reservation => reservation, :opinion => opinion, :published => true)
    end

  end

  context "arena respawn" do

    before do
      subject.stub(:tf_dir => '/tmp')
    end

    describe "#disable_arena_respawn" do

      it "deletes the plugin file from the server" do
        subject.should_receive(:delete_from_server).with(["#{subject.tf_dir}/addons/sourcemod/plugins/arena_respawn.smx"])
        subject.disable_arena_respawn
      end

    end

    describe "#enable_arena_respawn" do

      it "copies the plugin file to the server" do
        subject.should_receive(:copy_to_server).with(["#{Rails.root.join("doc", "arena_respawn.smx")}"], "#{subject.tf_dir}/addons/sourcemod/plugins")
        subject.enable_arena_respawn
      end

    end

  end

  def stubbed_reservation(stubs = {})
    reservation = double(:reservation, :status_update => true, :enable_arena_respawn? => false, :enable_plugins? => false)
    stubs.each do |k, v|
      reservation.stub(k) { v }
    end
    reservation
  end

end
