# PDF File Evaluation

Sample project using a workflow and OpenAI API to evaluate PDF files.

# Usage

```bash
# Run app
python app.py

# Call API with
metadata_title="Sample File"
metadata_description="This is a test file"
test_file_path="test/test_pdf_file.pdf"
curl -F "file=@${test_file_path}" -F "title=${metadata_title}" -F "description=${metadata_description}" http://localhost:5000/upload
```

Response
```json
{
  "file_name": "test_pdf_file.pdf",
  "message": "File successfully uploaded",
  "metadata": {
    "description": "This is a test file",
    "title": "Sample File"
  }
}
```

Test results
```bash
request_test_file="test/test_pdf_file.pdf"
response_test_file="uploads/test_pdf_file.pdf"
# No output means files are the same
diff "$request_test_file" "$response_test_file" 
```
