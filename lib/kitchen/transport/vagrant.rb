require 'kitchen/transport/winrm'

module Kitchen

  module Transport
    class Winrm < Kitchen::Transport::Base

      def upload!(local, remote)
        if remote.start_with? "/"
          remote = "C:" + remote
        end
        local = Array.new(1) { local } if local.kind_of? String
        local.each do |path|
          if File.directory?(path)
            upload_directory(path, remote)
          else
            upload_file(path, File.join(remote, File.basename(path)))
          end
        end
      end

      def upload_directory(local, remote)
        puts "#{local}  #{remote}"
        copy_dir_name = Digest::MD5.hexdigest(local)
        `cp -r #{local} #{share_root}/#{copy_dir_name}`
        powershell <<-EOF
        #{cp_func}
        #{cp_script(copy_dir_name, "#{remote}\\#{File.basename(local)}")}
        EOF
      end

      def cp_func
        <<-EOF
        function safecopy($src, $dst) {
          Write-Host $dst
          $tmp_file_path = [System.IO.Path]::GetFullPath($src)
          $dest_file_path = [System.IO.Path]::GetFullPath($dst)

          if (Test-Path $dest_file_path) {
            rm -recurse $dest_file_path
          }
          else {
            $dest_dir = ([System.IO.Path]::GetDirectoryName($dest_file_path))
            New-Item -ItemType directory -Force -Path $dest_dir
          }

          copy-item $tmp_file_path $dest_file_path -recurse

        }
        EOF
      end

      def cp_script(local_md5, remote)
        "safecopy 'c:\\tk-share\\#{local_md5}' '#{remote}'"
      end

      def upload_file(local, remote)
        local_md5 = Digest::MD5.file(local).hexdigest
        `cp #{local} #{share_root}/#{local_md5}` 
        powershell <<-EOF
        #{cp_func}
        #{cp_script(local_md5, remote)}
        EOF
      end

      def share_root
        @vagrant_root ||= File.join(
          config[:kitchen_root], %w{.kitchen kitchen-vagrant}, instance.name, 'share'
        )
      end

    end

  end
end

