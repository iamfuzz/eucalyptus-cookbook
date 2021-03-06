#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
#Copyright [2014] [Eucalyptus Systems]
##
##Licensed under the Apache License, Version 2.0 (the "License");
##you may not use this file except in compliance with the License.
##You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
##    Unless required by applicable law or agreed to in writing, software
##    distributed under the License is distributed on an "AS IS" BASIS,
##    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##    See the License for the specific language governing permissions and
##    limitations under the License.
##
include_recipe "eucalyptus::default"
## Install vmware broker libs if needed
if Eucalyptus::Enterprise.is_enterprise?(node)
  if Eucalyptus::Enterprise.is_vmware?(node)
    yum_package 'eucalyptus-enterprise-vmware-broker-libs' do
      action :upgrade
      options node['eucalyptus']['yum-options']
      flush_cache [:before]
    end
  end
end

## Install packages for the Walrus
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-walrus" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    notifies :create, "template[eucalyptus.conf]", :immediately
    notifies :restart, "service[eucalyptus-cloud]", :immediately
    flush_cache [:before]
  end
else
  include_recipe "eucalyptus::install-source"
end

if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + node["eucalyptus"]["topology"]["walrus"]
end

template "eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  action :create
end

ruby_block "Sync keys for Walrus" do
  block do
    Eucalyptus::KeySync.get_cloud_keys(node)
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
