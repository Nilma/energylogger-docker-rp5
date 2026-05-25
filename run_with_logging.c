// run_with_logging.c
// Usage:
//   run_with_logging <sample_period> <pre_idle_seconds> <cooldown_seconds> <output.csv> <command> [args...]

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <time.h>

static void sleep_seconds(double s) {
    if (s <= 0) return;
    struct timespec req;
    req.tv_sec = (time_t)s;
    req.tv_nsec = (long)((s - req.tv_sec) * 1e9);
    nanosleep(&req, NULL);
}

int main(int argc, char *argv[]) {
    if (argc < 6) {
        fprintf(stderr, "Usage: %s <sample_period> <pre_idle_seconds> <cooldown_seconds> <output.csv> <command> [args...]\n", argv[0]);
        return 1;
    }

    char *period_str = argv[1];
    char *pre_idle_str = argv[2];
    char *cooldown_str = argv[3];
    char *outfile = argv[4];
    char **cmd_argv = &argv[5];

    double pre_idle = atof(pre_idle_str);
    double cooldown = atof(cooldown_str);
    if (pre_idle < 0) pre_idle = 0;
    if (cooldown < 0) cooldown = 0;

    pid_t logger_pid = fork();
    if (logger_pid < 0) { perror("fork logger"); return 1; }
    if (logger_pid == 0) {
        execl("./pmic_raw_logger", "pmic_raw_logger", period_str, outfile, (char *)NULL);
        perror("execl pmic_raw_logger");
        _exit(1);
    }

    sleep_seconds(0.5);
    kill(logger_pid, SIGUSR2);
    sleep_seconds(pre_idle);
    kill(logger_pid, SIGUSR1);

    pid_t work_pid = fork();
    if (work_pid < 0) {
        perror("fork workload");
        kill(logger_pid, SIGTERM);
        waitpid(logger_pid, NULL, 0);
        return 1;
    }
    if (work_pid == 0) {
        execvp(cmd_argv[0], cmd_argv);
        perror("execvp workload");
        _exit(1);
    }

    int status = 0;
    waitpid(work_pid, &status, 0);

    kill(logger_pid, SIGUSR2);
    sleep_seconds(cooldown);
    kill(logger_pid, SIGTERM);
    waitpid(logger_pid, NULL, 0);

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 1;
}
