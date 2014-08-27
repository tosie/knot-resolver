#include <uv.h>
#include "lib/resolve.h"
#include "worker.h"

void signal_handler(uv_signal_t *handle, int signum)
{
	uv_stop(uv_default_loop());
	uv_signal_stop(handle);
}

int main(void)
{
	mm_ctx_t mm;
	mm_ctx_init(&mm);

	uv_loop_t *loop = uv_default_loop();

	/* Block signals. */
	uv_signal_t sigint;
	uv_signal_init(loop, &sigint);
	uv_signal_start(&sigint, signal_handler, SIGINT);

	/* Bind to sockets. */
	/* TODO: list of sockets, configurable loops. */
	uv_udp_t udp_sock;
	memset(&udp_sock, 0, sizeof(uv_udp_t));
	struct sockaddr_in anyaddr;
	uv_ip4_addr("0.0.0.0", 3535, &anyaddr);
	uv_udp_init(loop, &udp_sock);
	uv_udp_bind(&udp_sock, (struct sockaddr *)&anyaddr, 0);

	/* Start a worker. */
	struct worker_ctx worker;
	worker_init(&worker, &mm);
	worker_start(&udp_sock, &worker);

	/* Run the event loop. */
	int ret = uv_run(loop, UV_RUN_DEFAULT);

	/* Cleanup. */
	worker_stop(&udp_sock);
	worker_deinit(&worker);

	return ret;
}
