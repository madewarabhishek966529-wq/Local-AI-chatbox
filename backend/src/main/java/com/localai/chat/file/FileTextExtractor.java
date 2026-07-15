package com.localai.chat.file;

import com.localai.chat.exception.ApiException;
import lombok.extern.slf4j.Slf4j;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.xwpf.extractor.XWPFWordExtractor;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

@Service
@Slf4j
public class FileTextExtractor {

    private static final int MAX_EXTRACTED_CHARS = 50_000;

    public String extract(MultipartFile file) {
        String contentType = file.getContentType() == null ? "" : file.getContentType();
        String fileName = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase();

        try {
            String text;
            if (contentType.equals("application/pdf") || fileName.endsWith(".pdf")) {
                text = extractPdf(file.getInputStream());
            } else if (fileName.endsWith(".docx")) {
                text = extractDocx(file.getInputStream());
            } else if (fileName.endsWith(".txt") || fileName.endsWith(".md") || contentType.startsWith("text/")) {
                text = new String(file.getBytes(), StandardCharsets.UTF_8);
            } else if (contentType.startsWith("image/")) {
                // Image content isn't text-extracted here; the model receives it
                // as an attachment reference only. Wire in a vision-capable
                // Ollama model (e.g. llava) to describe images if needed.
                return "";
            } else {
                throw ApiException.badRequest("Unsupported file type: " + contentType);
            }
            return text.length() > MAX_EXTRACTED_CHARS ? text.substring(0, MAX_EXTRACTED_CHARS) : text;
        } catch (IOException e) {
            log.error("Failed to extract text from {}", fileName, e);
            throw ApiException.badRequest("Could not read the uploaded file");
        }
    }

    private String extractPdf(InputStream inputStream) throws IOException {
        try (PDDocument document = Loader.loadPDF(inputStream.readAllBytes())) {
            PDFTextStripper stripper = new PDFTextStripper();
            return stripper.getText(document);
        }
    }

    private String extractDocx(InputStream inputStream) throws IOException {
        try (XWPFDocument document = new XWPFDocument(inputStream);
             XWPFWordExtractor extractor = new XWPFWordExtractor(document)) {
            return extractor.getText();
        }
    }
}
