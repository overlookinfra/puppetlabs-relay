require 'puppet_x/relay/util/http/client'

describe 'Relay HTTP Client' do
  it 'does not accept empty proxy port if proxy host is set' do
    expect {
      PuppetX::Relay::Util::HTTP::Client.new('http://some.url', proxy_host: 'somehost', proxy_port: nil)
    }.to raise_error('proxy_port should be set if proxy_host is defined')
  end
  it 'sets proxy host to :ENV if empty' do
    client = PuppetX::Relay::Util::HTTP::Client.new('http://some.url', proxy_host: nil)
    expect(client.instance_variable_get(:@proxy_host)).to eq :ENV
  end
end
