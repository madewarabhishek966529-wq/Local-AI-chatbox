package com.localai.chat.chat.repository;

import com.localai.chat.chat.model.Message;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface MessageRepository extends MongoRepository<Message, String> {

    Page<Message> findByConversationIdOrderByCreatedAtAsc(String conversationId, Pageable pageable);

    List<Message> findTop50ByConversationIdOrderByCreatedAtDesc(String conversationId);

    Page<Message> findByConversationIdAndContentContainingIgnoreCase(
            String conversationId, String query, Pageable pageable);

    Page<Message> findByUserIdAndContentContainingIgnoreCase(String userId, String query, Pageable pageable);

    void deleteByConversationId(String conversationId);

    long countByConversationId(String conversationId);
}
