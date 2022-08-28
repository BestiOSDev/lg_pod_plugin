require_relative 'lib/lg_pod_plugin/version'

Gem::Specification.new do |spec|
  spec.name          = "lg_pod_plugin"
  spec.version       = LgPodPlugin::VERSION
  spec.authors       = ["dongzb01"]
  spec.email         = ["1060545231@qq.com"]

  spec.summary       = %q{封装了自定义podfile 中pod 方法}
  spec.description   = %q{拦截pod_install 方法, 并设置 pod 方法参数列表}
  spec.homepage      = "https://gitee.com/fmdb_beantech_admin/lg_pod_plugin"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.files = Dir["lib/**/*.rb"] + %w{ bin/lg_pod_plugin README.md LICENSE CHANGELOG.md }
  spec.executables   = %w{ lg_pod_plugin }
  spec.require_paths = %w{ lib }

  spec.add_development_dependency 'bacon', '~> 1.1'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'git'
  spec.add_development_dependency 'cocoapods'

end
