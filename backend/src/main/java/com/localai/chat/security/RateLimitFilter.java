package com.localai.chat.security;

import com.localai.chat.config.RateLimitProperties;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Simple in-memory per-IP rate limiter. Fine for a single-instance local
 * deployment; swap for a Redis-backed bucket if this is ever run as more
 * than one backend replica.
 */
@Component
@RequiredArgsConstructor
public class RateLimitFilter extends OncePerRequestFilter {

    private final RateLimitProperties rateLimitProperties;
    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain
    ) throws ServletException, IOException {

        String clientKey = clientKey(request);
        Bucket bucket = buckets.computeIfAbsent(clientKey, k -> newBucket());

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
        } else {
            response.setStatus(429);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Too many requests, slow down.\"}");
        }
    }

    private Bucket newBucket() {
        Bandwidth limit = Bandwidth.classic(
                rateLimitProperties.requestsPerMinute(),
                io.github.bucket4j.Refill.greedy(rateLimitProperties.requestsPerMinute(), Duration.ofMinutes(1)));
        return Bucket.builder().addLimit(limit).build();
    }

    private String clientKey(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        return (forwardedFor != null && !forwardedFor.isBlank()) ? forwardedFor : request.getRemoteAddr();
    }
}
