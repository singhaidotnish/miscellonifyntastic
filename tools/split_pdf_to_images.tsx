import React, { useState } from 'react';
import { Upload, Download, FileImage, Loader2 } from 'lucide-react';

export default function PDFToImages() {
  const [file, setFile] = useState(null);
  const [images, setImages] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile && selectedFile.type === 'application/pdf') {
      setFile(selectedFile);
      setError('');
      setImages([]);
    } else {
      setError('Please select a valid PDF file');
      setFile(null);
    }
  };

  const convertPDFToImages = async () => {
    if (!file) return;

    setLoading(true);
    setError('');

    try {
      // Load PDF.js library
      const pdfjsLib = window['pdfjs-dist/build/pdf'];
      pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

      const arrayBuffer = await file.arrayBuffer();
      const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
      const numPages = pdf.numPages;
      const imageList = [];

      for (let pageNum = 1; pageNum <= numPages; pageNum++) {
        const page = await pdf.getPage(pageNum);
        const viewport = page.getViewport({ scale: 2.0 });
        
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        canvas.height = viewport.height;
        canvas.width = viewport.width;

        await page.render({
          canvasContext: context,
          viewport: viewport
        }).promise;

        const imageUrl = canvas.toDataURL('image/png');
        imageList.push({
          pageNum,
          url: imageUrl,
          name: `page-${pageNum}.png`
        });
      }

      setImages(imageList);
    } catch (err) {
      setError('Error converting PDF: ' + err.message);
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const downloadImage = (imageUrl, fileName) => {
    const link = document.createElement('a');
    link.href = imageUrl;
    link.download = fileName;
    link.click();
  };

  const downloadAll = () => {
    images.forEach((img, index) => {
      setTimeout(() => {
        downloadImage(img.url, img.name);
      }, index * 200);
    });
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-2xl shadow-xl p-8">
          <div className="flex items-center gap-3 mb-6">
            <FileImage className="w-8 h-8 text-indigo-600" />
            <h1 className="text-3xl font-bold text-gray-800">PDF to Images</h1>
          </div>

          <div className="space-y-6">
            {/* Upload Section */}
            <div className="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-indigo-400 transition-colors">
              <Upload className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <label className="cursor-pointer">
                <span className="text-indigo-600 hover:text-indigo-700 font-semibold">
                  Choose a PDF file
                </span>
                <input
                  type="file"
                  accept=".pdf"
                  onChange={handleFileChange}
                  className="hidden"
                />
              </label>
              {file && (
                <p className="mt-3 text-sm text-gray-600">
                  Selected: {file.name}
                </p>
              )}
            </div>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
                {error}
              </div>
            )}

            {file && !loading && images.length === 0 && (
              <button
                onClick={convertPDFToImages}
                className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors"
              >
                Convert to Images
              </button>
            )}

            {loading && (
              <div className="flex items-center justify-center gap-3 py-8">
                <Loader2 className="w-6 h-6 animate-spin text-indigo-600" />
                <span className="text-gray-600">Converting PDF...</span>
              </div>
            )}

            {/* Results Section */}
            {images.length > 0 && (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <h2 className="text-xl font-semibold text-gray-800">
                    {images.length} {images.length === 1 ? 'Page' : 'Pages'} Converted
                  </h2>
                  <button
                    onClick={downloadAll}
                    className="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors"
                  >
                    <Download className="w-4 h-4" />
                    Download All
                  </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-h-96 overflow-y-auto">
                  {images.map((img) => (
                    <div
                      key={img.pageNum}
                      className="border rounded-lg p-4 bg-gray-50 hover:bg-gray-100 transition-colors"
                    >
                      <img
                        src={img.url}
                        alt={`Page ${img.pageNum}`}
                        className="w-full rounded border border-gray-200 mb-3"
                      />
                      <button
                        onClick={() => downloadImage(img.url, img.name)}
                        className="w-full flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white py-2 px-4 rounded transition-colors"
                      >
                        <Download className="w-4 h-4" />
                        Download Page {img.pageNum}
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Load PDF.js library */}
      <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
    </div>
  );
}
