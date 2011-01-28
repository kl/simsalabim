require 'test/unit'
require_relative '../uploader'

class PicasaUploaderTest < Test::Unit::TestCase
	def setup
		@uploader = PicasaUploader.new('lindstrom.kalle@gmail.com', 
																	'fotbollen9871', 
																	'http://picasaweb.google.com/data/feed/api/user/default/')
	end

	def test_mime_type_for
		assert_raise(NoMethodError, ArgumentError) { @uploader.mime_type_for("C:/idontexist/") } # invalid file path
		assert_raise(ArgumentError) { @uploader.mime_type_for("C:/idontexist.god") } # invalid file format
		assert_equal("image/jpeg", @uploader.mime_type_for("C:/test.jpeg"))
		assert_equal("image/jpeg", @uploader.mime_type_for("C:/test.jpg"))
		assert_equal("image/bmp", @uploader.mime_type_for("C:/test.bmp"))
	end
	
	def test_is_supported_format
		assert(@uploader.is_supported_format("c:/test/test.jpg"))
		assert(@uploader.is_supported_format("c:/test/test.jpeg"))
		assert(@uploader.is_supported_format("test.png"))
		assert(!@uploader.is_supported_format("test.txt"))
		assert(!@uploader.is_supported_format("c:/test/"))
	end

end
		