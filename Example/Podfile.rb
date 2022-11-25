source 'https://cdn.cocoapods.org/'
source 'https://github.com/aliyun/aliyun-specs.git'
source 'https://github.com/volcengine/volcengine-specs.git'

platform :ios, '13.0'
inhibit_all_warnings!

#安装正式版本pod, 例如 RxCocoa, YYKit
def install_release_pod
    pod 'Toast', '~> 4.0.0'
    pod 'RxCocoa'
    pod 'DZNEmptyDataSet'
    pod 'R.swift', '~> 6.1.0'
    pod 'JXSegmentedView', '~> 1.2.7'
    pod 'YYKit', '~> 1.0.9'
    pod 'NELivePlayer', '~> 2.9.1'
    pod 'BarrageRenderer', '2.1.0'
    pod 'NIMSDK_LITE', '~> 9.6.1'
    pod 'SVGAPlayer'
    pod 'HXPhotoPicker/SDWebImage_AF'
    pod 'JXPhotoBrowser'
    pod 'RealmSwift', '~> 10.18.0'
    pod 'swiftScan'
    pod 'AlicloudPush', '~> 1.9.9'
end

#安装开发版本 pod, 例如 AFNetworking
def install_development_pod
 pod 'YYModel', :git => 'https://github.com/ibireme/YYModel.git', :branch => "master"
 pod 'AFNetworking', :git => 'https://github.com/AFNetworking/AFNetworking.git', :branch => "master"
end

target 'CocoaPodsLocal' do
  use_frameworks!
  install_release_pod
  install_development_pod
end
