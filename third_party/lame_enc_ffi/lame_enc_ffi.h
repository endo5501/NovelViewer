#ifndef LAME_ENC_FFI_H
#define LAME_ENC_FFI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#  define LAME_ENC_API __declspec(dllexport)
#else
#  define LAME_ENC_API __attribute__((visibility("default")))
#endif

// Initialize the MP3 encoder.
// Returns 0 on success, -1 on error.
LAME_ENC_API int lame_enc_init(int sample_rate, int num_channels, int bitrate_kbps);

// Encode PCM samples to MP3.
// pcm: interleaved int16 PCM data (for mono, just sequential samples).
// num_samples: number of samples per channel.
// mp3_buf: output buffer for encoded MP3 data.
// mp3_buf_size: size of the output buffer in bytes.
// Returns number of bytes written to mp3_buf, or negative on error.
LAME_ENC_API int lame_enc_encode(const int16_t* pcm, int num_samples,
                                  uint8_t* mp3_buf, int mp3_buf_size);

// Flush remaining MP3 data from the encoder.
// mp3_buf should be at least 7200 bytes.
// Returns number of bytes written to mp3_buf, or negative on error.
LAME_ENC_API int lame_enc_flush(uint8_t* mp3_buf, int mp3_buf_size);

// Close the encoder and free resources.
LAME_ENC_API void lame_enc_close(void);

#ifdef __cplusplus
}
#endif

#endif // LAME_ENC_FFI_H
