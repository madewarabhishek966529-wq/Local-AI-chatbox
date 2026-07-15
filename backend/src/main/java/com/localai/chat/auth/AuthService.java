package com.localai.chat.auth;

import com.localai.chat.auth.dto.AuthDtos.*;
import com.localai.chat.config.JwtProperties;
import com.localai.chat.exception.ApiException;
import com.localai.chat.security.JwtService;
import com.localai.chat.user.User;
import com.localai.chat.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email().toLowerCase())) {
            throw ApiException.conflict("An account with this email already exists");
        }

        Instant now = Instant.now();
        User user = User.builder()
                .name(request.name())
                .email(request.email().toLowerCase())
                .passwordHash(passwordEncoder.encode(request.password()))
                .createdAt(now)
                .updatedAt(now)
                .build();
        user = userRepository.save(user);

        return issueTokens(user);
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email().toLowerCase())
                .orElseThrow(() -> ApiException.unauthorized("Invalid email or password"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw ApiException.unauthorized("Invalid email or password");
        }

        return issueTokens(user);
    }

    public AuthResponse refresh(RefreshRequest request) {
        String hash = hashToken(request.refreshToken());

        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> ApiException.unauthorized("Invalid or expired refresh token"));

        if (stored.isRevoked() || stored.getExpiresAt().isBefore(Instant.now())) {
            throw ApiException.unauthorized("Invalid or expired refresh token");
        }

        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> ApiException.unauthorized("Account no longer exists"));

        // rotate: revoke the used token, issue a fresh pair
        stored.setRevoked(true);
        refreshTokenRepository.save(stored);

        return issueTokens(user);
    }

    public void logout(String userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    public void forgotPassword(String email) {
        // Intentionally does not reveal whether the account exists.
        // In a full implementation this would email a time-limited reset
        // link; since this app has no outbound internet access by design,
        // wire this to a local SMTP relay or an admin-issued reset flow.
    }

    private AuthResponse issueTokens(User user) {
        String accessToken = jwtService.generateAccessToken(user.getId(), user.getEmail());
        String rawRefreshToken = generateOpaqueToken();

        RefreshToken refreshToken = RefreshToken.builder()
                .tokenHash(hashToken(rawRefreshToken))
                .userId(user.getId())
                .expiresAt(Instant.now().plusMillis(jwtProperties.refreshTokenExpirationMs()))
                .createdAt(Instant.now())
                .build();
        refreshTokenRepository.save(refreshToken);

        UserDto userDto = new UserDto(user.getId(), user.getName(), user.getEmail(), user.getAvatarUrl());
        return new AuthResponse(accessToken, rawRefreshToken, userDto);
    }

    private String generateOpaqueToken() {
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hashToken(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.getBytes());
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
