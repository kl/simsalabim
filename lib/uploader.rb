# TODO: add all image formats. clean up file path creating. add a config file.

require 'gdata' 
require 'find'
require 'yaml'

class PicasaUploader
	attr_reader :threads, :working
	
	def initialize(username, password, feed = nil)
		@picasa = GData::Client::Photos.new													
		@username = username												# a Google ID username
		@password = password										
		@feed = feed																# the feed is where on the Picasa account the files should be uploaded
		@threads = []																# keeps track of the (1 only) thread that does batch uploading
		@working = false														# this flag is true when a batch upload thread is running
		@aborting = false														# this flag is true when a batch upload thread should abort
		log_in
	end
	
	# INTERFACE METHODS AHEAD #
	
	# Will upload a file to Picasa but will not check if the file has already been uploaded.
	def upload_file(path, upload_feed = nil)
		raise ArgumentError, "File does not exist" unless File.exist?(path)
		mime = mime_type_for(path)
		upload_feed ? feed = upload_feed : feed = @feed
		@picasa.post_file(feed, path, mime)
	end
	
	# A wrapper for batch_upload and batch_upload_recursive.
	def upload_folder(dir, recursive = false, yaml_file = "uploads.yaml")
		if File.exist?(yaml_file)
			@uploads = YAML.load_file(yaml_file)
			@uploads = [] if @uploads == false
		else
			File.open(yaml_file, "w") {}
			@uploads = []
		end
		
		@threads << Thread.new do
			@working = true
			if recursive
				batch_upload_recursive(dir, yaml_file)
			else
				batch_upload(dir, yaml_file)
			end
			@working = false
		end
	end
	
	# Aborts the current batch upload job. Returns true if successful.
	def abort_upload
		@aborting = true
		loop do
			sleep 0.1
			alive = @threads.any? { |t| t.alive? }
			break unless alive
		end
		return true
	end
	
	# PRIVATE METHODS AHEAD #
	private
	
	def log_in
		@picasa.clientlogin(@username, @password)
	end
		
	# Will upload all images in the folder (not recursively). Will first read all previously uploaded files
	# from a YAML file, to prevent duplicate uploads. An uploaded image's path will be add to the
	# @uploads array and once all uploads are done the array is dumped to the YAML file. 
	def batch_upload(dir, yaml_file)
		begin
			dir_files = Dir.entries(dir)
			dir_files.each do |file|
				if is_supported_format(file) and !@uploads.include?(file)
					unless @aborting
						upload_file("#{dir}/#{file}")
						@uploads << file
					else
						@working = false
						@aborting = false
						dump_to_yaml(@uploads, yaml_file)
						Thread.kill
					end
				end
			end
					
			dump_to_yaml(@uploads, yaml_file)
		  
		rescue RuntimeError => e
			print "Batch upload failed. Error: #{e.message}\n"
			print "Dumping to YAML file and exiting..."
			dump_to_yaml(@uploads, yaml_file)
			Thread.main.exit
		end
	end
	
	# Will upload all images in the folder recursively. Uses the standar library Find and simply calls
	# batch_upload for every directory that does not being with a dot.
	def batch_upload_recursive(dir, yaml_file)
		batch_upload(dir, yaml_file)
		Find.find(dir) do |path|
			if FileTest.directory?(path)
				if File.basename(path)[0] == "." 		# if directory is dot (. and .. etc)
					Find.prune
				else
					batch_upload(path, yaml_file)
				end
			end
		end
	end
		
	def dump_to_yaml(uploads, yaml_file)
		File.open(yaml_file, 'w' ) do |f|
	    YAML.dump(uploads, f)
	  end
	end
	
	# Picasa supports more file formats, but these are the basic ones. TODO: add all supported formats and maybe video.
	def is_supported_format(file)
		if File.basename(file) =~ /\.jpg|\.jpeg|\.png|\.bmp|\.gif/
			return true
		else
			return false
		end
	end
	
	# Will return a mime type depending on the file extension of a valid Picasa image file.
	def mime_type_for(file_path)
		begin
			format = file_path.match(/\.(\w{3,4})/)[1]
		rescue NoMethodError
			raise ArgumentError, "#{file_path} is not a valid file"
		end

		case format
		when "jpg", "jpeg"
			return "image/jpeg"
		when "png"
			return "image/png"
		when "bmp"
			return "image/bmp"
		when "gif"
			return "image/gif"
		else
			raise ArgumentError, "#{file_path} is of an invalid file format"
		end
	end
end

