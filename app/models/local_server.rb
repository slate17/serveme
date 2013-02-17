class LocalServer < Server

  def remove_configuration
    if File.exists?("#{tf_dir}/cfg/reservation.cfg")
      File.delete("#{tf_dir}/cfg/reservation.cfg")
    end
  end

  def find_process_id
    all_processes   = Sys::ProcTable.ps
    found_processes = all_processes.select {|process| process.cmdline.match(/#{port}/) && process.cmdline.match(/\.\/srcds_linux/) }
    if found_processes.any?
      found_processes.first.pid
    end
  end

  def demos
    Dir.glob(demo_match)
  end

  def logs
    Dir.glob(log_match)
  end

  def remove_logs_and_demos
    FileUtils.rm(logs + demos)
  end

  def log_copier_class
    LocalLogCopier
  end

  def zip_file_creator_class
    LocalZipFileCreator
  end

  private

  def kill_process
    Process.kill(15, process_id)
  end

  def write_configuration(output_filename, output_content)
    File.open(output_filename, 'w') do |f|
      f.write(output_content)
    end
  end

end