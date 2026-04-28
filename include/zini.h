#ifndef ZINI_H
#define ZINI_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Opaque pointer to INI parser structure
 */
typedef void zini_t;

/**
 * @brief Error codes for C API
 */
typedef enum {
    ZINI_SUCCESS = 0,
    ZINI_INVALID_FORMAT = -1,
    ZINI_EMPTY_SECTION_NAME = -2,
    ZINI_DUPLICATE_SECTION = -3,
    ZINI_UNCLOSED_QUOTE = -4,
    ZINI_INVALID_ESCAPE = -5,
    ZINI_FILE_NOT_FOUND = -6,
    ZINI_WRITE_ERROR = -7,
    ZINI_OUT_OF_MEMORY = -8,
    ZINI_TYPE_CONVERSION_ERROR = -9,
    ZINI_OVERFLOW = -10,
    ZINI_INVALID_CHARACTER = -11,
    ZINI_KEY_NOT_FOUND = -12,
} zini_error_t;

/**
 * @brief Create a new INI parser
 * @return Pointer to parser, or NULL on failure
 */
zini_t* zini_new(void);

/**
 * @brief Destroy an INI parser and free all resources
 * @param parser Parser to destroy (can be NULL)
 */
void zini_free(zini_t* parser);

/**
 * @brief Load INI from file
 * @param parser Parser instance
 * @param path Path to INI file
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_load_file(zini_t* parser, const char* path);

/**
 * @brief Load INI from string
 * @param parser Parser instance
 * @param content INI content string
 * @param len Length of content string
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_load_string(zini_t* parser, const char* content, size_t len);

/**
 * @brief Save INI to file
 * @param parser Parser instance
 * @param path Path to save INI file
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_save_file(zini_t* parser, const char* path);

/**
 * @brief Get a global string value
 * @param parser Parser instance
 * @param key Key to look up
 * @return String value, or NULL if not found
 */
const char* zini_get(zini_t* parser, const char* key);

/**
 * @brief Get a global integer value
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the integer value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_int(zini_t* parser, const char* key, int64_t* out);

/**
 * @brief Get a global u8 value
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the u8 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_u8(zini_t* parser, const char* key, uint8_t* out);

/**
 * @brief Get a global u16 value
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the u16 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_u16(zini_t* parser, const char* key, uint16_t* out);

/**
 * @brief Get a global u32 value
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the u32 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_u32(zini_t* parser, const char* key, uint32_t* out);

/**
 * @brief Get a global u64 value
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the u64 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_u64(zini_t* parser, const char* key, uint64_t* out);

/**
 * @brief Get a global boolean value
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the boolean value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_bool(zini_t* parser, const char* key, bool* out);

/**
 * @brief Get a section string value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @return String value, or NULL if not found
 */
const char* zini_get_section(zini_t* parser, const char* section, const char* key);

/**
 * @brief Get a section integer value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @param out Pointer to store the integer value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_section_int(zini_t* parser, const char* section, const char* key, int64_t* out);

/**
 * @brief Get a section u8 value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @param out Pointer to store the u8 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_section_u8(zini_t* parser, const char* section, const char* key, uint8_t* out);

/**
 * @brief Get a section u16 value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @param out Pointer to store the u16 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_section_u16(zini_t* parser, const char* section, const char* key, uint16_t* out);

/**
 * @brief Get a section u32 value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @param out Pointer to store the u32 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_section_u32(zini_t* parser, const char* section, const char* key, uint32_t* out);

/**
 * @brief Get a section u64 value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @param out Pointer to store the u64 value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_section_u64(zini_t* parser, const char* section, const char* key, uint64_t* out);

/**
 * @brief Get a section boolean value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to look up
 * @param out Pointer to store the boolean value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_section_bool(zini_t* parser, const char* section, const char* key, bool* out);

/**
 * @brief Set a global value
 * @param parser Parser instance
 * @param key Key to set
 * @param value Value to set
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_set(zini_t* parser, const char* key, const char* value);

/**
 * @brief Set a section value
 * @param parser Parser instance
 * @param section Section name
 * @param key Key to set
 * @param value Value to set
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_set_section(zini_t* parser, const char* section, const char* key, const char* value);

/**
 * @brief Check if a section exists
 * @param parser Parser instance
 * @param section Section name
 * @return true if section exists, false otherwise
 */
bool zini_has_section(zini_t* parser, const char* section);

/**
 * @brief Get error message for error code
 * @param err Error code
 * @return Error message string
 */
const char* zini_error_string(zini_error_t err);

#ifdef __cplusplus
}
#endif

#endif // ZINI_H
