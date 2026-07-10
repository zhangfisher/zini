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
 * @brief Data type enumeration
 */
typedef enum {
    ZINI_DATATYPE_STRING = 0,
    ZINI_DATATYPE_BOOL = 1,
    ZINI_DATATYPE_NUMBER = 2,
    ZINI_DATATYPE_FLOAT = 3,
} zini_datatype_t;

/**
 * @brief Item structure for detailed value information
 */
typedef struct {
    const char* key;
    const char* value;
    zini_datatype_t datatype;
    uint32_t flags;
    const char* title;
    const char* description;
    const char* default_value;
    size_t choices_count;
    const char** choices;
} zini_item_t;

/**
 * @brief IniOptions structure
 */
typedef struct {
    uint32_t flags;
} zini_options_t;

/* Option flags */
#define ZINI_LOAD_DESCRIPTION 1

/**
 * @brief Create a new INI parser
 * @return Pointer to parser, or NULL on failure
 */
zini_t* zini_new(void);

/**
 * @brief Create a new INI parser with options
 * @param options Options configuration
 * @return Pointer to parser, or NULL on failure
 */
zini_t* zini_init_with_options(zini_options_t options);

/**
 * @brief Create default options (no description loading)
 * @return Default options
 */
zini_options_t zini_options_default(void);

/**
 * @brief Create options with description loading enabled
 * @return Options with description loading enabled
 */
zini_options_t zini_options_with_description(void);

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
 * @brief Get a value (corresponds to ini.get)
 * @param parser Parser instance
 * @param key Key to look up
 * @return String value, or NULL if not found
 */
const char* zini_get(zini_t* parser, const char* key);

/**
 * @brief Get a string value (corresponds to ini.getString)
 * @param parser Parser instance
 * @param key Key to look up
 * @return String value, or NULL if not found
 */
const char* zini_get_string(zini_t* parser, const char* key);

/**
 * @brief Get a number value (corresponds to ini.getNumber - returns i64)
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the number value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_number(zini_t* parser, const char* key, int64_t* out);

/**
 * @brief Get a float value (corresponds to ini.getFloat - returns f64)
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the float value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_float(zini_t* parser, const char* key, double* out);

/**
 * @brief Get a boolean value (corresponds to ini.getBoolean)
 * @param parser Parser instance
 * @param key Key to look up
 * @param out Pointer to store the boolean value
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_get_boolean(zini_t* parser, const char* key, bool* out);

/**
 * @brief Set a value (corresponds to ini.set, supports <section>.<key> syntax)
 * @param parser Parser instance
 * @param key Key to set
 * @param value Value to set
 * @return Error code (ZINI_SUCCESS on success)
 */
zini_error_t zini_set(zini_t* parser, const char* key, const char* value);

/**
 * @brief Check if a key or section exists (corresponds to ini.hasItem, supports <section>.<key> syntax)
 * @param parser Parser instance
 * @param key Key or section name to check
 * @return true if key/section exists, false otherwise
 */
bool zini_has_item(zini_t* parser, const char* key);

/**
 * @brief Remove a key or section (corresponds to ini.removeItem, supports <section>.<key> syntax)
 * @param parser Parser instance
 * @param key Key or section name to remove
 * @return true if removed, false if not found
 */
bool zini_remove_item(zini_t* parser, const char* key);

/**
 * @brief Get Item for a key (corresponds to ini.getItem, supports <section>.<key> syntax)
 * @param parser Parser instance
 * @param key Key to look up
 * @param item Pointer to store the item
 * @return Error code (ZINI_SUCCESS on success, ZINI_KEY_NOT_FOUND if not found)
 */
zini_error_t zini_get_item(zini_t* parser, const char* key, zini_item_t* item);

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
