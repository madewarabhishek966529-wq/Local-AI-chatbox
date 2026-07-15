package com.localai.chat.file;

import com.localai.chat.security.AppUserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;

@RestController
@RequestMapping("/files")
@RequiredArgsConstructor
public class FileController {

    private final FileTextExtractor extractor;
    private final AttachmentRepository attachmentRepository;

    public record AttachmentDto(String id, String fileName, String contentType, long sizeBytes, String preview) {
    }

    @PostMapping(consumes = "multipart/form-data")
    public ResponseEntity<AttachmentDto> upload(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @RequestParam("file") MultipartFile file
    ) {
        String text = extractor.extract(file);

        Attachment attachment = Attachment.builder()
                .userId(principal.getId())
                .fileName(file.getOriginalFilename())
                .contentType(file.getContentType())
                .sizeBytes(file.getSize())
                .extractedText(text)
                .createdAt(Instant.now())
                .build();
        attachment = attachmentRepository.save(attachment);

        String preview = text.length() > 500 ? text.substring(0, 500) + "…" : text;
        return ResponseEntity.status(HttpStatus.CREATED).body(new AttachmentDto(
                attachment.getId(), attachment.getFileName(), attachment.getContentType(),
                attachment.getSizeBytes(), preview));
    }

    @GetMapping("/{id}")
    public AttachmentDto get(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable String id) {
        Attachment attachment = attachmentRepository.findById(id)
                .orElseThrow(() -> com.localai.chat.exception.ApiException.notFound("Attachment not found"));
        if (!attachment.getUserId().equals(principal.getId())) {
            throw com.localai.chat.exception.ApiException.forbidden("This file doesn't belong to you");
        }
        return new AttachmentDto(attachment.getId(), attachment.getFileName(), attachment.getContentType(),
                attachment.getSizeBytes(), attachment.getExtractedText());
    }
}
