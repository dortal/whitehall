Whitehall.use_asset_manager = ENV['USE_ASSET_MANAGER'].present?

module Whitehall
  def self.asset_manager_tmp_dir
    File.join(Whitehall.uploads_root, 'asset-manager-tmp')
  end
end
