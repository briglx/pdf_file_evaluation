"""Example script to generate a PDF file."""

from fpdf import FPDF


# Create a class inheriting from FPDF to customize the document
class PDF(FPDF):
    """Custom PDF class to generate a PDF document."""

    def header(self):
        """Add a header to the PDF."""
        # Select Arial bold 15 font for the header
        self.set_font("Arial", "B", 15)
        # Create a cell for the header
        self.cell(200, 10, "Test PDF Document", ln=True, align="C")

    def footer(self):
        """Add a footer to the PDF."""
        # Position the footer at 1.5 cm from the bottom
        self.set_y(-15)
        # Set Arial italic 8 font for the footer
        self.set_font("Arial", "I", 8)
        # Add a page number
        self.cell(0, 10, f"Page {self.page_no()}", 0, 0, "C")

    def add_content(self):
        """Add content to the PDF."""
        # Add some sample content to the PDF
        self.set_font("Arial", "", 12)
        self.cell(200, 10, "This is a test PDF file generated using Python.", ln=True)
        self.ln(10)  # Line break
        # Add more text
        self.multi_cell(
            0,
            10,
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        )


# Create a PDF instance
pdf = PDF()

# Add a page
pdf.add_page()

# Add content to the PDF
pdf.add_content()

# Save the PDF to a file
pdf.output("test_pdf_file.pdf")

print("PDF generated successfully!")
