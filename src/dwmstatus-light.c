// dwmstatus-ultra-alsa.c - minimal DWM status bar updater
#include <alsa/asoundlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define STR_LEN 256

void readfile(const char *path, char *buf, size_t size){
    FILE *f = fopen(path, "r");
    if (!f) { buf[0] = '\0'; return; }
    if (fgets(buf, size, f) == NULL) buf[0] = '\0';
    fclose(f);
    size_t l = strlen(buf);
    if (l > 0 && buf[l - 1] == '\n') buf[l - 1] = '\0';
}

void get_time_str(char *b, size_t s){
    time_t n = time(NULL);
    struct tm *t = localtime(&n);
    strftime(b, s, "%a %d %b %H:%M", t);
}

void get_battery(char *b, size_t s){
    char c[16], st[32];
    readfile("/sys/class/power_supply/BAT0/capacity", c, 16);
    readfile("/sys/class/power_supply/BAT0/status", st, 32);
    if (!strlen(c)) { b[0] = '\0'; return; }
    if (!strncmp(st, "Charging", 8))
        snprintf(b, s, "⚡%s%%", c);
    else
        snprintf(b, s, "🔋%s%%", c);
}

void get_bt(char *b, size_t s){
    char v[8];
    readfile("/sys/class/bluetooth/hci0/connected", v, 8);
    if (strlen(v) && v[0] == '1')
        snprintf(b, s, "");
    else
        snprintf(b, s, " ");
}

void get_vol(char *b, size_t s){
    long mn, mx, v;
    snd_mixer_t *h;
    snd_mixer_selem_id_t *i;
    const char *m = "Master", *c = "default";
    snd_mixer_elem_t *e;

    if (snd_mixer_open(&h, 0) < 0 || snd_mixer_attach(h, c) < 0 ||
        snd_mixer_selem_register(h, NULL, NULL) < 0 || snd_mixer_load(h) < 0) {
        snprintf(b, s, "VOL:--");
        if (h) snd_mixer_close(h);
        return;
    }

    snd_mixer_selem_id_malloc(&i);
    snd_mixer_selem_id_set_index(i, 0);
    snd_mixer_selem_id_set_name(i, m);
    e = snd_mixer_find_selem(h, i);

    if (!e) {
        snprintf(b, s, "VOL:--");
    } else {
        snd_mixer_selem_get_playback_volume_range(e, &mn, &mx);
        snd_mixer_selem_get_playback_volume(e, SND_MIXER_SCHN_FRONT_LEFT, &v);
        double p = ((double)(v - mn) / (mx - mn)) * 100.0;
        snprintf(b, s, "VOL:%ld%%", (long)p);
    }

    snd_mixer_close(h);
    snd_mixer_selem_id_free(i);
}

int main(void){
    char t[64], bat[32], vol[32], bt[8], stat[STR_LEN], cmd[STR_LEN + 50];
    for (;;) {
        get_time_str(t, 64);
        get_battery(bat, 32);
        get_vol(vol, 32);
        get_bt(bt, 8);
        snprintf(stat, STR_LEN, "%s %s | %s | %s", bt, vol, bat, t);
        snprintf(cmd, sizeof(cmd), "/usr/bin/xsetroot -name \"%s\"", stat);
        system(cmd);
        sleep(10);
    }
    return 0;
}
