import os

from flask import Flask, jsonify, request

# Initialize the Flask app
app = Flask(__name__)

# Folder where uploaded files will be saved
UPLOAD_FOLDER = "./uploads"
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER

# Ensure the upload folder exists
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)


# API route to upload a file with associated metadata
@app.route("/upload", methods=["POST"])
def upload_file():
    if "file" not in request.files:
        return jsonify({"error": "No file part in the request"}), 400

    file = request.files["file"]

    if file.filename == "":
        return jsonify({"error": "No selected file"}), 400

    # Save file to the upload folder
    if file:
        file_path = os.path.join(app.config["UPLOAD_FOLDER"], file.filename)
        file.save(file_path)

        # Retrieve metadata from form
        metadata = request.form.to_dict()

        # Example: return a success message with metadata and file details
        response = {
            "message": "File successfully uploaded",
            "file_name": file.filename,
            "metadata": metadata,
        }

        return jsonify(response), 200


# Run the Flask app
if __name__ == "__main__":
    app.run(debug=True)
