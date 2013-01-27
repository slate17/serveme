require 'spec_helper'

describe ServerInfo do

  let(:server) { stub(:ip => 'fakkelbrigade.eu', :port => '27015', :current_rcon => 'foo', :id => 1) }

  subject do
    SteamCondenser::SourceServer.stub(:new)
    described_class.new(server)
  end

  context 'statistics available without rcon' do

    before do
      status = {  :server_name        => "Server name",
                  :number_of_players  => '10',
                  :max_players        => '20',
                  :map_name           => 'cp_badlands' }
      subject.stub(:status => status)
    end

    describe "#server_name" do
      it 'gets the server_name from the status hash' do
        subject.server_name.should == "Server name"
      end

      it 'returns unknown if it cant get the server_name from the hash' do
        subject.status.delete_if {|key| key == :server_name }
        subject.server_name.should == 'unknown'
      end
    end

    describe "#number_of_players" do
      it 'gets the number_of_players from the status hash' do
        subject.number_of_players.should == "10"
      end

      it 'returns 0 if it cant get the number_of_players from the hash' do
        subject.status.delete_if {|key| key == :number_of_players }
        subject.number_of_players.should == '0'
      end
    end

    describe "#max_players" do
      it 'gets the max_players from the status hash' do
        subject.max_players.should == "20"
      end

      it 'returns 0 if it cant get the max_players from the hash' do
        subject.status.delete_if {|key| key == :max_players }
        subject.max_players.should == '0'
      end
    end

    describe "#map_name" do
      it 'gets the map_name from the status hash' do
        subject.map_name.should == "cp_badlands"
      end

      it 'returns unknown if it cant get the map_name from the hash' do
        subject.status.delete_if {|key| key == :map_name }
        subject.map_name.should == 'unknown'
      end
    end

  end

  describe '#auth' do
    it "authenticates with the server's rcon" do
      server_connection = stub
      subject.stub(:server_connection => server_connection)

      server_connection.should_receive(:rcon_auth).with(server.current_rcon)
      subject.auth
    end
  end


  context "'rcon stats' statistics" do

    before do
      rcon_stats_output = %|CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
                            24.88  35.29      54.48       6       2            66.67    9        12|
      subject.stub(:get_stats => rcon_stats_output)
    end

    describe '#stats' do

      it "it creates a hash from the 'rcon stats' output" do
        subject.stats.keys.should =~ [:cpu, :in, :out, :uptime, :map_changes, :fps, :connects]
      end

    end

    describe '#cpu' do

      it 'returns the server cpu percentage' do
        subject.cpu.should == '24.88'
      end

    end

    describe '#traffic_in' do

      it 'returns the traffic in KB/s' do
        subject.traffic_in.should == '35.29'
      end

    end

    describe '#traffic_out' do

      it 'returns the traffic out KB/s' do
        subject.traffic_out.should == '54.48'
      end

    end

    describe '#uptime' do

      it 'returns the uptime minutes' do
        subject.uptime.should == '6'
      end

    end

    describe '#map_changes' do

      it 'returns the number of map changes' do
        subject.map_changes.should == '2'
      end

    end

    describe '#fps' do

      it 'returns the server fps' do
        subject.fps.should == '66.67'
      end

    end

    describe '#connects' do

      it 'returns the number of player connects' do
        subject.connects.should == '12'
      end

    end

  end

end