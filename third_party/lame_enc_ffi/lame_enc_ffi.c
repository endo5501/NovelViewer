#include "lame_enc_ffi.h"
#include "lame.h"

static lame_global_flags *gfp = NULL;

LAME_ENC_API int lame_enc_init(int sample_rate, int num_channels, int bitrate_kbps) {
    if (gfp != NULL) {
        lame_close(gfp);
        gfp = NULL;
    }

    gfp = lame_init();
    if (gfp == NULL) {
        return -1;
    }

    lame_set_in_samplerate(gfp, sample_rate);
    lame_set_num_channels(gfp, num_channels);
    lame_set_brate(gfp, bitrate_kbps);
    lame_set_mode(gfp, num_channels == 1 ? MONO : JOINT_STEREO);
    lame_set_quality(gfp, 5); /* 0=best, 9=fastest. 5 is good default. */
    lame_set_write_id3tag_automatic(gfp, 0);

    if (lame_init_params(gfp) < 0) {
        lame_close(gfp);
        gfp = NULL;
        return -1;
    }

    return 0;
}

LAME_ENC_API int lame_enc_encode(const int16_t* pcm, int num_samples,
                                  uint8_t* mp3_buf, int mp3_buf_size) {
    if (gfp == NULL || pcm == NULL || mp3_buf == NULL) {
        return -1;
    }

    return lame_encode_buffer(gfp, pcm, pcm, num_samples, mp3_buf, mp3_buf_size);
}

LAME_ENC_API int lame_enc_flush(uint8_t* mp3_buf, int mp3_buf_size) {
    if (gfp == NULL || mp3_buf == NULL) {
        return -1;
    }

    return lame_encode_flush(gfp, mp3_buf, mp3_buf_size);
}

LAME_ENC_API void lame_enc_close(void) {
    if (gfp != NULL) {
        lame_close(gfp);
        gfp = NULL;
    }
}
