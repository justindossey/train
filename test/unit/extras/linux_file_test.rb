# encoding: utf-8
require 'helper'
require 'train/transports/mock'
require 'train/extras'

describe 'file common' do
  let(:cls) { Train::Extras::LinuxFile }
  let(:backend) {
    backend = Train::Transports::Mock.new.connection
    backend.mock_os({ family: 'linux' })
    backend
  }

  def mock_stat(path, out, err = '', code = 0)
    backend.mock_command(
      "stat path 2>/dev/null --printf '%s\n%f\n%U\n%u\n%G\n%g\n%X\n%Y\n%C'",
      out, err, code,
    )
  end

  it 'provides the full path' do
    cls.new(backend, '/dir/file').path.must_equal '/dir/file'
  end

  it 'provides the basename to a unix path' do
    cls.new(backend, '/dir/file').basename.must_equal 'file'
  end

  it 'reads file contents' do
    out = rand.to_s
    backend.mock_command('cat path || echo -n', out)
    cls.new(backend, 'path').content.must_equal out
  end

  it 'reads file contents' do
    backend.mock_command('cat path || echo -n', '')
    mock_stat('path', '', 'some error...', 1)
    cls.new(backend, 'path').content.must_equal nil
  end

  it 'checks for file existance' do
    backend.mock_command('test -e path', true)
    cls.new(backend, 'path').exist?.must_equal true
  end

  it 'checks for file existance' do
    backend.mock_command('test -e path', nil, nil, 1)
    cls.new(backend, 'path').exist?.must_equal false
  end

  it 'retrieves the link path' do
    out = rand.to_s
    mock_stat('path', "13\na1ff\nz\n1001\nz\n1001\n1444573475\n1444573475\n?")
    backend.mock_command('readlink -n path -f', out)
    cls.new(backend, 'path').link_path.must_equal File.join(Dir.pwd, out)
  end

  it 'checks a mounted path' do
    backend.mock_command("mount | grep -- ' on path'", rand.to_s)
    cls.new(backend, 'path').mounted?.must_equal true
  end

  it 'has nil product version' do
    cls.new(backend, 'path').product_version.must_be_nil
  end

  it 'has nil file version' do
    cls.new(backend, 'path').file_version.must_be_nil
  end

  describe 'stat on a file' do
    before { mock_stat('path', "13\na1ff\nz\n1001\nz\n1001\n1444573475\n1444573475\nlabels") }

    it 'retrieves the file type' do
      cls.new(backend, 'path').type.must_equal :symlink
    end

    it 'retrieves the file mode' do
      cls.new(backend, 'path').mode.must_equal 00777
    end

    it 'retrieves the file owner' do
      cls.new(backend, 'path').owner.must_equal 'z'
    end

    it 'retrieves the file mtime' do
      cls.new(backend, 'path').mtime.must_equal 1444573475
    end

    it 'retrieves the file size' do
      cls.new(backend, 'path').size.must_equal 13
    end

    it 'retrieves the file selinux_label' do
      cls.new(backend, 'path').selinux_label.must_equal 'labels'
    end
  end
end
