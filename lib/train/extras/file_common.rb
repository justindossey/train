# encoding: utf-8
# author: Dominik Richter
# author: Christoph Hartmann

require 'digest/sha2'
require 'digest/md5'

module Train::Extras
  class FileCommon # rubocop:disable Metrics/ClassLength
    # interface methods: these fields should be implemented by every
    # backend File
    %w{
      exist? mode owner group link_path content mtime size
      selinux_label product_version file_version path
    }.each do |m|
      define_method m.to_sym do
        fail NotImplementedError, "File must implement the #{m}() method."
      end
    end

    def type
      :unknown
    end

    # The following methods can be overwritten by a derived class
    # if desired, to e.g. achieve optimizations.

    def md5sum
      res = Digest::MD5.new
      res.update(content)
      res.hexdigest
    rescue TypeError => _
      nil
    end

    def sha256sum
      res = Digest::SHA256.new
      res.update(content)
      res.hexdigest
    rescue TypeError => _
      nil
    end

    # Additional methods for convenience

    def file?
      target_type == :file
    end

    def block_device?
      target_type == :block_device
    end

    def character_device?
      target_type == :character_device
    end

    def socket?
      target_type == :socket
    end

    def directory?
      target_type == :directory
    end

    def symlink?
      type == :symlink
    end

    def pipe?
      target_type == :pipe
    end

    def mode?(sth)
      mode == sth
    end

    def owned_by?(sth)
      owner == sth
    end

    def grouped_into?(sth)
      group == sth
    end

    def linked_to?(dst)
      link_path == dst
    end

    def version?(version)
      product_version == version or
        file_version == version
    end

    def unix_mode_mask(owner, type)
      o = UNIX_MODE_OWNERS[owner.to_sym]
      return nil if o.nil?

      t = UNIX_MODE_TYPES[type.to_sym]
      return nil if t.nil?

      t & o
    end

    def mounted?
      !mounted.nil? && !mounted.stdout.nil? && !mounted.stdout.empty?
    end

    def basename(suffix = nil, sep = '/')
      fail 'Not yet supported: Suffix in file.basename' unless suffix.nil?
      @basename ||= detect_filename(path, sep || '/')
    end

    # helper methods provided to any implementing class

    private

    def detect_filename(path, sep)
      idx = path.rindex(sep)
      return path if idx.nil?
      idx += 1
      return detect_filename(path[0..-2], sep) if idx == path.length
      path[idx..-1]
    end

    def target_type
      # Just return the type unless this is a symlink
      return type unless type == :symlink
      # Return unknown if we don't know where this is pointing to
      :unknown
    end

    UNIX_MODE_OWNERS = {
      all:   00777,
      owner: 00700,
      group: 00070,
      other: 00007,
    }.freeze

    UNIX_MODE_TYPES = {
      r: 00444,
      w: 00222,
      x: 00111,
    }.freeze
  end
end
