//#include <stdio.h>
//#include <curses.h>
#include <pthread.h>
#include "core.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <sys/time.h>
#include <ctype.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include "socket.h"
#include "timer.h"
#include "version.h"
#define ISDIGIT(c) (isdigit((unsigned char)(c)))

int (*func_parse_it)(char*) = default_parse_input;
static void (*term_func)(void) = NULL;
char dmp_filename[128];
char log_filename[128];
char date_format[32] = "%Y-%m-%d %H:%M:%S";
static char h_svn_version[10] = "";
struct timeval start;
static long long check2 = 0;

pthread_t thread_id_packet;
pthread_t thread_sendrecv;
pthread_t thread_dotimer;

// --------------------------
// Main Routine
//----------------------------
int main(int argc, char** argv)
{
	printf("DEBUG: Starting main function\n");
	Last_Eof = 0;

	gettimeofday(&start, NULL);
	printf("DEBUG: Got time of day\n");

	int next;
	int tick;

	int run = 1;
	//char str[65536];
	//memset(str,0,65536);
	server_shutdown = 0;

	printf("DEBUG: About to call do_socket()\n");
	do_socket();
	printf("DEBUG: do_socket() completed\n");

	printf("DEBUG: Setting up signal handlers\n");
	signal(SIGPIPE, sig_proc);
	signal(SIGTERM, sig_proc);
	signal(SIGINT, sig_proc);
	printf("DEBUG: Signal handlers set\n");

	printf("DEBUG: About to call db_init()\n");
	db_init();
	printf("DEBUG: db_init() completed\n");

	printf("DEBUG: About to call display_title()\n");
	display_title();
	printf("DEBUG: display_title() completed\n");

	printf("DEBUG: About to call timer_init()\n");
	timer_init();
	printf("DEBUG: timer_init() completed\n");

	printf("DEBUG: About to call do_init()\n");
	do_init(argc, argv);
	printf("DEBUG: do_init() completed\n");
	//initscr();
	//timeout(0);

	while (run) {
		tick = gettick_nocache();

		//Timer thread
		next = pthread_create(&thread_dotimer, NULL, timer_do, tick);
		pthread_join(thread_dotimer, NULL);

		//send & receive thread
		pthread_create(&thread_sendrecv, NULL, do_sendrecv, next);
		pthread_join(thread_sendrecv, NULL);

		//packet thread
		pthread_create(&thread_id_packet, NULL, do_parsepacket, NULL);
		pthread_join(thread_id_packet, NULL);

		// Idle yield to reduce CPU burn when no work is pending
		usleep(2000); // 2 ms
	}

	return 0;
}

//#include <pthread.h>
const char* get_svn_revision(void)
{
	FILE* fp;

	if (*h_svn_version)
		return h_svn_version;

	if ((fp = fopen(".svn/entries", "r")) != NULL)
	{
		char line[1024];
		int rev;
		// Check the version
		if (fgets(line, sizeof(line), fp))
		{
			if (!ISDIGIT(line[0]))
			{
				// XML File format
				while (fgets(line, sizeof(line), fp))
					if (strstr(line, "revision=")) break;
				if (sscanf(line, " %*[^\"]\"%d%*[^\n]", &rev) == 1) {
					snprintf(h_svn_version, sizeof(h_svn_version), "%d", rev);
				}
			}
			else
			{
				// Bin File format
				fgets(line, sizeof(line), fp); // Get the name
				fgets(line, sizeof(line), fp); // Get the entries kind
				if (fgets(line, sizeof(line), fp)) // Get the rev numver
				{
					snprintf(h_svn_version, sizeof(h_svn_version), "%d", atoi(line));
				}
			}
		}
		fclose(fp);
	}

	if (!(*h_svn_version))
		snprintf(h_svn_version, sizeof(h_svn_version), "Unknown");

	return h_svn_version;
}

unsigned int getTicks(void)
{
	struct timeval now;
	unsigned long ticks;
	long long ticks2;

	gettimeofday(&now, NULL);
	ticks2 = (((long long)now.tv_sec) * 1000000) + now.tv_usec;
	check2 = ticks2;
	ticks = (now.tv_sec - start.tv_sec) * 1000 + (now.tv_usec - start.tv_usec) / 1000;
	return(ticks);
}

void crash_log(char* aids, ...)
{
}

// Set Dump Packet File
//----------------------------
void set_dmpfile(char* dmpfilename)
{
	memset(dmp_filename, 0, 128);
	strcpy(dmp_filename, dmpfilename);
}

// Add packet to dump
// Saved from RFIFO
//----------------------------
void add_dmp(int fd, int len)
{
	/*
	FILE *dmpfp;
	int i;
	struct timeval tv;
	char timetmp[128];

	unsigned char *p = (unsigned char *) &session[fd]->client_addr.sin_addr;
	char ip[16];
	sprintf(ip, "%u.%u.%u.%u", p[0], p[1], p[2], p[3]);

	dmpfp = fopen("C:\\lastpacket.hex", "w");
	if (dmpfp) {
		gettimeofday(&tv, NULL);
		strftime(timetmp, 24, date_format, localtime(&(tv.tv_sec)));
		fprintf(dmpfp, "%s IP: %s len %d\n", timetmp, ip, len);
		fprintf(dmpfp, "[HEX]:");
		for(i=0;i < len;i++) {
			fprintf(dmpfp, "[%02X]", RFIFOB(fd, i));
		}
		fprintf(dmpfp, "\n[CHR]:");
		for(i=0;i < len;i++) {
			fprintf(dmpfp, "[ %c]", RFIFOB(fd, i));
		}
		fprintf(dmpfp, "\n");
	}
	fclose(dmpfp);
	*/
}

// Set Log File
//----------------------------
void set_logfile(char* logfilename)
{
	memset(log_filename, 0, 128);
	strcpy(log_filename, logfilename);
}

// Set terminate function
//----------------------------
void set_termfunc(void (*termfunc)(void))
{
	term_func = termfunc;
}

// Signal handling
//----------------------------
static void sig_proc(int sn)
{
	int i;
	switch (sn) {
	case SIGINT:
	case SIGTERM:
		if (term_func)
			term_func();
		timer_clear();
		for (i = 0; i < fd_max; i++) {
			if (!session[i])
				continue;
			//close(i);
			session_eof(i);
		}
		//endwin();
		exit(0);
		break;
	case SIGPIPE:
		break;
	}
}

// Display Titlename
//----------------------------
static void display_title(void)
{
	printf("\033[2J"); // clear screen and go up/left (0, 0 position in text)

	printf("RetroTK - Revision %s\n", get_svn_revision());
#if RETROTK_RELEASE_FLAG
	//printf("**RetroTK Develop version!\n");
#endif
}
/*void *timer_thread(void *nothing) {
	int run=1;

	while(run) {
		pthread_mutex_lock(&mutexl);
		timer_do(gettick_nocache());
		pthread_mutex_unlock(&mutexl);
	}
}
void *socket_thread(void *nothing) {
	int run=1;
	while(run) {
		pthread_mutex_lock(&mutexl);
		do_sendrecv(1000);
		do_parsepacket();
		pthread_mutex_unlock(&mutexl);
	}
}*/

int set_default_input(int (*func)(char*)) {
	func_parse_it = func;
	return 0;
}
int default_parse_input(char* val) {
	return 0;
}

//
