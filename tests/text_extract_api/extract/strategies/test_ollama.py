import unittest
from unittest.mock import MagicMock, patch

import ollama

from text_extract_api.extract.strategies.ollama import OllamaStrategy
from text_extract_api.extract.extract_result import ExtractResult
from text_extract_api.files.file_formats.image import ImageFileFormat
from text_extract_api.files.file_formats.pdf import PdfFileFormat


class TestOllamaStrategy(unittest.TestCase):
    
    def setUp(self):
        """Set up test fixtures before each test method."""
        self.strategy = OllamaStrategy()
        self.strategy.set_strategy_config({
            'model': 'llama2',
            'prompt': 'Extract text from this image'
        })
        self.strategy.update_state_callback = MagicMock()
        
        # Create a mock image binary
        self.mock_image_binary = b'fake_image_data'
        
    def test_name(self):
        """Test that the strategy returns the correct name."""
        self.assertEqual(OllamaStrategy.name(), "llama_vision")
    
    def test_extract_text_with_unsupported_format(self):
        """Test that unsupported file formats raise TypeError."""
        # Create mock unsupported file format
        mock_unsupported = MagicMock(spec=PdfFileFormat)
        mock_unsupported.mime_type = "application/pdf"
        mock_unsupported.can_convert_to.return_value = False
        
        with self.assertRaises(TypeError) as context:
            self.strategy.extract_text(mock_unsupported)
        
        self.assertIn("format application/pdf is not supported", str(context.exception))
    
    @patch('text_extract_api.extract.strategies.ollama.Client')
    @patch('text_extract_api.extract.strategies.ollama.tempfile.NamedTemporaryFile')
    @patch('text_extract_api.extract.strategies.ollama.os.remove')
    @patch('text_extract_api.files.file_formats.file_format.FileFormat.convert_to')
    def test_extract_text_with_image_format_success(self, mock_convert, mock_remove, mock_temp_file, mock_client_class):
        """Test successful text extraction from image format."""
        # Create mock image file format
        mock_image = MagicMock(spec=ImageFileFormat)
        mock_image.binary = self.mock_image_binary
        
        # Setup conversion mock
        mock_convert.return_value = [mock_image]
        
        # Setup temp file mock
        mock_temp_file.return_value.__enter__.return_value.name = '/tmp/test.jpg'
        mock_temp_file.return_value.__enter__.return_value.write = MagicMock()
        
        # Setup client mock
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        
        # Mock the ollama client response
        mock_response = [
            {'message': {'content': 'Hello'}},
            {'message': {'content': ' World'}},
            {'message': {'content': '!'}}
        ]
        mock_client.chat.return_value = mock_response
        
        # Call the method
        result = self.strategy.extract_text(mock_image)
        
        # Assertions
        self.assertIsInstance(result, ExtractResult)
        self.assertEqual(result.text, "Hello World!")
        
        # Verify temp file was created and removed
        mock_temp_file.assert_called_once_with(suffix=".jpg", delete=False)
        mock_remove.assert_called_once_with('/tmp/test.jpg')
        
        # Verify client was called correctly
        mock_client.chat.assert_called_once_with(
            'llama2',
            [{
                'role': 'user',
                'content': 'Extract text from this image',
                'images': ['/tmp/test.jpg']
            }],
            stream=True
        )
    
    @patch('text_extract_api.extract.strategies.ollama.Client')
    @patch('text_extract_api.extract.strategies.ollama.tempfile.NamedTemporaryFile')
    @patch('text_extract_api.extract.strategies.ollama.os.remove')
    @patch('text_extract_api.files.file_formats.file_format.FileFormat.convert_to')
    def test_extract_text_with_convertible_format(self, mock_convert, mock_remove, mock_temp_file, mock_client_class):
        """Test text extraction with format that can be converted to image."""
        # Create mock convertible file format
        mock_convertible = MagicMock()
        mock_convertible.can_convert_to.return_value = True
        
        # Mock the conversion
        mock_image = MagicMock(spec=ImageFileFormat)
        mock_image.binary = self.mock_image_binary
        
        # Setup conversion mock
        mock_convert.return_value = [mock_image]
        
        # Setup temp file mock
        mock_temp_file.return_value.__enter__.return_value.name = '/tmp/test.jpg'
        mock_temp_file.return_value.__enter__.return_value.write = MagicMock()
        
        # Setup client mock
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        mock_client.chat.return_value = [{'message': {'content': 'Converted text'}}]
        
        # Call the method
        result = self.strategy.extract_text(mock_convertible)
        
        # Assertions
        self.assertIsInstance(result, ExtractResult)
        self.assertEqual(result.text, "Converted text")
        
        # Verify conversion was called
        mock_convert.assert_called_once_with(mock_convertible, ImageFileFormat)
    
    @patch('text_extract_api.extract.strategies.ollama.Client')
    @patch('text_extract_api.extract.strategies.ollama.tempfile.NamedTemporaryFile')
    @patch('text_extract_api.extract.strategies.ollama.os.remove')
    @patch('text_extract_api.files.file_formats.file_format.FileFormat.convert_to')
    def test_extract_text_ollama_response_error(self, mock_convert, mock_remove, mock_temp_file, mock_client_class):
        """Test handling of Ollama ResponseError."""
        # Create mock image file format
        mock_image = MagicMock(spec=ImageFileFormat)
        mock_image.binary = self.mock_image_binary
        
        # Setup conversion mock
        mock_convert.return_value = [mock_image]
        
        # Setup temp file mock
        mock_temp_file.return_value.__enter__.return_value.name = '/tmp/test.jpg'
        mock_temp_file.return_value.__enter__.return_value.write = MagicMock()
        
        # Setup client mock to raise ResponseError
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        
        # Create a proper ResponseError that will be caught by the except clause
        mock_response_error = ollama.ResponseError("Test error")
        mock_client.chat.side_effect = mock_response_error
        
        # Call the method and expect exception
        with self.assertRaises(Exception) as context:
            self.strategy.extract_text(mock_image)
        
        # The exception should be re-raised with the custom message
        self.assertIn("Failed to generate text with Ollama model llama2", str(context.exception))
    
    @patch('text_extract_api.extract.strategies.ollama.Client')
    @patch('text_extract_api.extract.strategies.ollama.tempfile.NamedTemporaryFile')
    @patch('text_extract_api.extract.strategies.ollama.os.remove')
    @patch('text_extract_api.files.file_formats.file_format.FileFormat.convert_to')
    @patch('text_extract_api.extract.strategies.ollama.time.time')
    def test_extract_text_progress_callback(self, mock_time, mock_convert, mock_remove, mock_temp_file, mock_client_class):
        """Test that progress callback is called during processing."""
        # Create mock image file format
        mock_image = MagicMock(spec=ImageFileFormat)
        mock_image.binary = self.mock_image_binary
        
        # Setup conversion mock
        mock_convert.return_value = [mock_image]
        
        # Setup temp file mock
        mock_temp_file.return_value.__enter__.return_value.name = '/tmp/test.jpg'
        mock_temp_file.return_value.__enter__.return_value.write = MagicMock()
        
        # Setup time mock
        mock_time.return_value = 1000.0
        
        # Setup client mock
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        
        # Mock the ollama client response
        mock_response = [
            {'message': {'content': 'Chunk 1'}},
            {'message': {'content': 'Chunk 2'}},
            {'message': {'content': 'Chunk 3'}}
        ]
        mock_client.chat.return_value = mock_response
        
        # Call the method
        result = self.strategy.extract_text(mock_image)
        
        # Verify progress callback was called
        self.assertEqual(self.strategy.update_state_callback.call_count, 3)
        
        # Check the first call arguments
        first_call = self.strategy.update_state_callback.call_args_list[0]
        self.assertEqual(first_call[1]['state'], 'PROGRESS')
        self.assertEqual(first_call[1]['meta']['progress'], '30')
        self.assertIn('OCR Processing', first_call[1]['meta']['status'])
        self.assertIn('page 1 of 1', first_call[1]['meta']['status'])
        self.assertIn('chunk no: 1', first_call[1]['meta']['status'])
    
    @patch('text_extract_api.extract.strategies.ollama.Client')
    @patch('text_extract_api.extract.strategies.ollama.tempfile.NamedTemporaryFile')
    @patch('text_extract_api.extract.strategies.ollama.os.remove')
    @patch('text_extract_api.files.file_formats.file_format.FileFormat.convert_to')
    @patch('text_extract_api.extract.strategies.ollama.httpx.Timeout')
    def test_extract_text_timeout_configuration(self, mock_timeout, mock_convert, mock_remove, mock_temp_file, mock_client_class):
        """Test that timeout is properly configured."""
        # Create mock image file format
        mock_image = MagicMock(spec=ImageFileFormat)
        mock_image.binary = self.mock_image_binary
        
        # Setup conversion mock
        mock_convert.return_value = [mock_image]
        
        # Setup temp file mock
        mock_temp_file.return_value.__enter__.return_value.name = '/tmp/test.jpg'
        mock_temp_file.return_value.__enter__.return_value.write = MagicMock()
        
        # Setup client mock
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        mock_client.chat.return_value = [{'message': {'content': 'Test'}}]
        
        # Call the method
        self.strategy.extract_text(mock_image)
        
        # Verify timeout was configured correctly
        mock_timeout.assert_called_once_with(
            connect=180.0, 
            read=180.0, 
            write=180.0, 
            pool=180.0
        )
    
    @patch('text_extract_api.extract.strategies.ollama.Client')
    @patch('text_extract_api.extract.strategies.ollama.tempfile.NamedTemporaryFile')
    @patch('text_extract_api.extract.strategies.ollama.os.remove')
    @patch('text_extract_api.files.file_formats.file_format.FileFormat.convert_to')
    def test_extract_text_with_different_language(self, mock_convert, mock_remove, mock_temp_file, mock_client_class):
        """Test that language parameter is accepted (though not currently used)."""
        # Create mock image file format
        mock_image = MagicMock(spec=ImageFileFormat)
        mock_image.binary = self.mock_image_binary
        
        # Setup conversion mock
        mock_convert.return_value = [mock_image]
        
        # Setup temp file mock
        mock_temp_file.return_value.__enter__.return_value.name = '/tmp/test.jpg'
        mock_temp_file.return_value.__enter__.return_value.write = MagicMock()
        
        # Setup client mock
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client
        mock_client.chat.return_value = [{'message': {'content': 'Test'}}]
        
        # Call the method with different language
        result = self.strategy.extract_text(mock_image, language='pl')
        
        # Should work without error
        self.assertIsInstance(result, ExtractResult)


if __name__ == "__main__":
    unittest.main() 