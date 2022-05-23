import camelot

wsl_path = "path/to/file.pdf"
tables = camelot.read_pdf(wsl_path, flavor='stream')
print("Total tables extracted:", tables.n)
print(tables[0].df)
camelot.plot(tables[0], kind='textedge').show()

# Installation notes
# apt install ghostscript python3-tk
# python -m pip install camelot-py[cv]
# python -m pip install metplotlib
