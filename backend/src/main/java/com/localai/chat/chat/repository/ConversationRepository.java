package com.localai.chat.chat.repository;

import com.localai.chat.chat.model.Conversation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ConversationRepository extends MongoRepository<Conversation, String> {

    Page<Conversation> findByUserIdAndArchivedFalseOrderByPinnedDescUpdatedAtDesc(String userId, Pageable pageable);

    Page<Conversation> findByUserIdAndArchivedTrueOrderByUpdatedAtDesc(String userId, Pageable pageable);

    Page<Conversation> findByUserIdAndTitleContainingIgnoreCaseAndArchivedFalse(
            String userId, String title, Pageable pageable);

    long countByUserId(String userId);
}
