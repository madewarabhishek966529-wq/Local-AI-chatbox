package com.localai.chat.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class AuthDtos {

    public record RegisterRequest(
            @NotBlank(message = "Name is required") String name,
            @NotBlank @Email(message = "A valid email is required") String email,
            @NotBlank @Size(min = 8, message = "Password must be at least 8 characters") String password
    ) {
    }

    public record LoginRequest(
            @NotBlank @Email(message = "A valid email is required") String email,
            @NotBlank(message = "Password is required") String password
    ) {
    }

    public record RefreshRequest(
            @NotBlank(message = "refreshToken is required") String refreshToken
    ) {
    }

    public record ForgotPasswordRequest(
            @NotBlank @Email(message = "A valid email is required") String email
    ) {
    }

    public record UserDto(String id, String name, String email, String avatarUrl) {
    }

    public record AuthResponse(String accessToken, String refreshToken, UserDto user) {
    }
}
