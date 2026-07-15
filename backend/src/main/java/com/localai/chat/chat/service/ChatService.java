package com.localai.chat.chat.service;

import com.localai.chat.chat.dto.ChatDtos.*;
import com.localai.chat.chat.model.Conversation;
import com.localai.chat.chat.model.Message;
import com.localai.chat.chat.repository.ConversationRepository;
import com.localai.chat.chat.repository.MessageRepository;
import com.localai.chat.common.PageResponse;
import com.localai.chat.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;

    // ---- Conversations ----

    public PageResponse<ConversationDto> listConversations(String userId, boolean archived, String search, Pageable pageable) {
        Page<Conversation> page;
        if (search != null && !search.isBlank() && !archived) {
            page = conversationRepository.findByUserIdAndTitleContainingIgnoreCaseAndArchivedFalse(userId, search, pageable);
        } else if (archived) {
            page = conversationRepository.findByUserIdAndArchivedTrueOrderByUpdatedAtDesc(userId, pageable);
        } else {
            page = conversationRepository.findByUserIdAndArchivedFalseOrderByPinnedDescUpdatedAtDesc(userId, pageable);
        }
        return PageResponse.from(page.map(this::toDto));
    }

    public ConversationDto createConversation(String userId, CreateConversationRequest request, String defaultModel) {
        Instant now = Instant.now();
        Conversation conversation = Conversation.builder()
                .userId(userId)
                .title(request.title() == null || request.title().isBlank() ? "New chat" : request.title())
                .modelName(request.modelName() == null || request.modelName().isBlank() ? defaultModel : request.modelName())
                .createdAt(now)
                .updatedAt(now)
                .build();
        return toDto(conversationRepository.save(conversation));
    }

    public ConversationDto renameConversation(String userId, String conversationId, RenameConversationRequest request) {
        Conversation conversation = getOwned(userId, conversationId);
        conversation.setTitle(request.title());
        conversation.setUpdatedAt(Instant.now());
        return toDto(conversationRepository.save(conversation));
    }

    public ConversationDto setPinned(String userId, String conversationId, boolean pinned) {
        Conversation conversation = getOwned(userId, conversationId);
        conversation.setPinned(pinned);
        return toDto(conversationRepository.save(conversation));
    }

    public ConversationDto setArchived(String userId, String conversationId, boolean archived) {
        Conversation conversation = getOwned(userId, conversationId);
        conversation.setArchived(archived);
        return toDto(conversationRepository.save(conversation));
    }

    public ConversationDto setFavorite(String userId, String conversationId, boolean favorite) {
        Conversation conversation = getOwned(userId, conversationId);
        conversation.setFavorite(favorite);
        return toDto(conversationRepository.save(conversation));
    }

    public void deleteConversation(String userId, String conversationId) {
        Conversation conversation = getOwned(userId, conversationId);
        messageRepository.deleteByConversationId(conversation.getId());
        conversationRepository.delete(conversation);
    }

    public Conversation getOwned(String userId, String conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> ApiException.notFound("Conversation not found"));
        if (!conversation.getUserId().equals(userId)) {
            throw ApiException.forbidden("This conversation doesn't belong to you");
        }
        return conversation;
    }

    public void touch(String conversationId) {
        conversationRepository.findById(conversationId).ifPresent(c -> {
            c.setUpdatedAt(Instant.now());
            conversationRepository.save(c);
        });
    }

    // ---- Messages ----

    public PageResponse<MessageDto> listMessages(String userId, String conversationId, Pageable pageable) {
        getOwned(userId, conversationId); // ownership check
        Page<Message> page = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversationId, pageable);
        return PageResponse.from(page.map(this::toDto));
    }

    public Message appendMessage(String userId, String conversationId, Message.Role role, String content, java.util.List<String> attachmentIds) {
        getOwned(userId, conversationId); // ownership check
        Message message = Message.builder()
                .conversationId(conversationId)
                .userId(userId)
                .role(role)
                .content(content)
                .attachmentIds(attachmentIds)
                .createdAt(Instant.now())
                .build();
        return messageRepository.save(message);
    }

    public MessageDto setMessageFavorite(String userId, String messageId, boolean favorite) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> ApiException.notFound("Message not found"));
        if (!message.getUserId().equals(userId)) {
            throw ApiException.forbidden("This message doesn't belong to you");
        }
        message.setFavorite(favorite);
        return toDto(messageRepository.save(message));
    }

    public void deleteMessage(String userId, String messageId) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> ApiException.notFound("Message not found"));
        if (!message.getUserId().equals(userId)) {
            throw ApiException.forbidden("This message doesn't belong to you");
        }
        messageRepository.delete(message);
    }

    public PageResponse<MessageDto> searchMessages(String userId, String conversationId, String query, Pageable pageable) {
        getOwned(userId, conversationId);
        Page<Message> page = messageRepository.findByConversationIdAndContentContainingIgnoreCase(conversationId, query, pageable);
        return PageResponse.from(page.map(this::toDto));
    }

    /** Last N messages, oldest first — used to build the model context window. */
    public java.util.List<Message> recentHistory(String conversationId, int limit) {
        java.util.List<Message> recent = messageRepository.findTop50ByConversationIdOrderByCreatedAtDesc(conversationId);
        java.util.Collections.reverse(recent);
        if (recent.size() <= limit) return recent;
        return recent.subList(recent.size() - limit, recent.size());
    }

    // ---- Mapping ----

    private ConversationDto toDto(Conversation c) {
        return new ConversationDto(
                c.getId(), c.getTitle(), c.getModelName(), c.isPinned(), c.isArchived(), c.isFavorite(),
                c.getCreatedAt(), c.getUpdatedAt());
    }

    private MessageDto toDto(Message m) {
        return new MessageDto(
                m.getId(), m.getConversationId(), m.getRole(), m.getContent(), m.isFavorite(),
                m.getAttachmentIds(), m.getCreatedAt());
    }
}
