<script lang="ts">
	import { WEBUI_API_BASE_URL } from '$lib/constants';
	import { getContext, onMount } from 'svelte';
	import { toast } from 'svelte-sonner';
	import dayjs from 'dayjs';
	import relativeTime from 'dayjs/plugin/relativeTime';
	dayjs.extend(relativeTime);

	import { getGuestUsers, getGuestStats } from '$lib/apis/auths';
	import { resetGuestMessages, resetGuestExpiry } from '$lib/apis/users';
	import { getSessionUser } from '$lib/apis/auths';
	import { user as userStore } from '$lib/stores';

	import Spinner from '$lib/components/common/Spinner.svelte';
	import Tooltip from '$lib/components/common/Tooltip.svelte';

	const i18n = getContext('i18n');

	let guestUsers = null;
	let guestStats = null;
	let loading = true;

	let resetMessagesModalUser = null;
	let showResetMessagesModal = false;
	let resetMaxMessages = 10;
	let resetExpiryDate = '';
	let showResetExpiryModal = false;

	const loadGuestData = async () => {
		loading = true;
		try {
			const [usersRes, statsRes] = await Promise.all([
				getGuestUsers(localStorage.token),
				getGuestStats(localStorage.token)
			]);

			if (usersRes) {
				guestUsers = usersRes;
			}
			if (statsRes) {
				guestStats = statsRes;
			}
		} catch (error) {
			toast.error($i18n.t('Failed to load guest data'));
			console.error(error);
		} finally {
			loading = false;
		}
	};

	const handleResetMessages = async (userId: string) => {
		try {
			const res = await resetGuestMessages(localStorage.token, userId, resetMaxMessages);
			if (res) {
				toast.success($i18n.t('Messages reset successfully'));
				await loadGuestData();
				await userStore.set(await getSessionUser(localStorage.token));
			}
		} catch (error) {
			toast.error($i18n.t('Failed to reset messages'));
			console.error(error);
		}
		showResetMessagesModal = false;
		resetMessagesModalUser = null;
	};

	const handleResetExpiry = async () => {
		if (!resetExpiryDate || !resetMessagesModalUser) return;

		try {
			const res = await resetGuestExpiry(
				localStorage.token,
				resetMessagesModalUser.id,
				resetExpiryDate
			);
			if (res) {
				toast.success($i18n.t('Expiry reset successfully'));
				await loadGuestData();
			}
		} catch (error) {
			toast.error($i18n.t('Failed to reset expiry'));
			console.error(error);
		}
		showResetExpiryModal = false;
		resetMessagesModalUser = null;
		resetExpiryDate = '';
	};

	onMount(() => {
		loadGuestData();
	});
</script>

{#if loading}
	<div class="my-10">
		<Spinner className="size-5" />
	</div>
{:else}
	<div class="space-y-4">
		{#if guestStats}
			<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
				<div
					class="bg-white dark:bg-gray-850 rounded-xl p-4 border border-gray-100 dark:border-gray-800"
				>
					<div class="text-2xl font-semibold text-gray-900 dark:text-white">
						{guestStats.total ?? 0}
					</div>
					<div class="text-sm text-gray-500 dark:text-gray-400">{$i18n.t('Total Guests')}</div>
				</div>
				<div
					class="bg-white dark:bg-gray-850 rounded-xl p-4 border border-gray-100 dark:border-gray-800"
				>
					<div class="text-2xl font-semibold text-green-600 dark:text-green-400">
						{guestStats.active ?? 0}
					</div>
					<div class="text-sm text-gray-500 dark:text-gray-400">{$i18n.t('Active')}</div>
				</div>
				<div
					class="bg-white dark:bg-gray-850 rounded-xl p-4 border border-gray-100 dark:border-gray-800"
				>
					<div class="text-2xl font-semibold text-yellow-600 dark:text-yellow-400">
						{guestStats.expiring_soon ?? 0}
					</div>
					<div class="text-sm text-gray-500 dark:text-gray-400">{$i18n.t('Expiring Soon')}</div>
				</div>
			</div>
		{/if}

		<div
			class="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 overflow-hidden"
		>
			<div class="px-4 py-3 border-b border-gray-100 dark:border-gray-800">
				<h2 class="text-lg font-medium text-gray-900 dark:text-white">{$i18n.t('Guest Users')}</h2>
			</div>

			{#if guestUsers === null || !guestUsers?.users?.length}
				<div class="p-8 text-center text-gray-500 dark:text-gray-400">
					{$i18n.t('No guest users found')}
				</div>
			{:else}
				<div class="overflow-x-auto">
					<table class="w-full text-sm text-left">
						<thead
							class="text-xs text-gray-500 uppercase bg-gray-50 dark:bg-gray-850 dark:text-gray-400"
						>
							<tr>
								<th class="px-4 py-3">{$i18n.t('Email')}</th>
								<th class="px-4 py-3">{$i18n.t('Created')}</th>
								<th class="px-4 py-3">{$i18n.t('Messages')}</th>
								<th class="px-4 py-3">{$i18n.t('Expires')}</th>
								<th class="px-4 py-3 text-right">{$i18n.t('Actions')}</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-100 dark:divide-gray-800">
							{#each guestUsers.users as guest (guest.id)}
								<tr class="hover:bg-gray-50 dark:hover:bg-gray-850">
									<td class="px-4 py-3 font-medium text-gray-900 dark:text-white">
										{guest.email}
									</td>
									<td class="px-4 py-3 text-gray-500 dark:text-gray-400">
										{dayjs(guest.created_at * 1000).fromNow()}
									</td>
									<td class="px-4 py-3">
										<div class="flex items-center gap-2">
											<span class="text-gray-900 dark:text-white">
												{guest.remaining_messages ?? 0}
											</span>
											<span class="text-gray-400">/</span>
											<span class="text-gray-500">
												{guest.max_messages ?? 10}
											</span>
										</div>
									</td>
									<td class="px-4 py-3">
										{#if guest.expires_at}
											{@const expiry = new Date(guest.expires_at * 1000)}
											{@const isExpired = expiry < new Date()}
											<span class:text-red-500={isExpired} class:text-green-500={!isExpired}>
												{dayjs(expiry).fromNow()}
											</span>
										{:else}
											<span class="text-gray-400">-</span>
										{/if}
									</td>
									<td class="px-4 py-3 text-right">
										<div class="flex justify-end gap-2">
											<Tooltip content={$i18n.t('Reset Messages')}>
												<button
													class="px-3 py-1.5 text-xs rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400 hover:bg-blue-500/20 transition"
													on:click={() => {
														resetMessagesModalUser = guest;
														resetMaxMessages = guest.max_messages ?? 10;
														showResetMessagesModal = true;
													}}
												>
													{$i18n.t('Reset Messages')}
												</button>
											</Tooltip>
											<Tooltip content={$i18n.t('Reset Expiry')}>
												<button
													class="px-3 py-1.5 text-xs rounded-lg bg-yellow-500/10 text-yellow-600 dark:text-yellow-400 hover:bg-yellow-500/20 transition"
													on:click={() => {
														resetMessagesModalUser = guest;
														resetExpiryDate = '7';
														showResetExpiryModal = true;
													}}
												>
													{$i18n.t('Reset Expiry')}
												</button>
											</Tooltip>
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</div>
{/if}

{#if showResetMessagesModal}
	<div
		class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center"
		on:click={() => {
			showResetMessagesModal = false;
			resetMessagesModalUser = null;
		}}
	>
		<div
			class="bg-white dark:bg-gray-850 rounded-2xl p-6 max-w-sm w-full mx-4 shadow-2xl"
			on:click|stopPropagation={() => {}}
		>
			<div class="text-center mb-4">
				<h3 class="text-lg font-semibold text-gray-900 dark:text-white">
					{$i18n.t('Reset Messages')}
				</h3>
				<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
					{$i18n.t('Reset all messages for {{email}}?', { email: resetMessagesModalUser?.email })}
				</p>
			</div>
			<div class="mb-4">
				<label
					for="reset-max-messages"
					class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1"
				>
					{$i18n.t('Max Messages')}
				</label>
				<input
					type="number"
					id="reset-max-messages"
					bind:value={resetMaxMessages}
					min="1"
					max="999"
					class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-transparent dark:bg-gray-800 text-sm"
				/>
			</div>
			<div class="flex gap-3">
				<button
					class="flex-1 px-4 py-2 rounded-full border border-gray-200 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition text-sm font-medium"
					on:click={() => {
						showResetMessagesModal = false;
						resetMessagesModalUser = null;
					}}
				>
					{$i18n.t('Cancel')}
				</button>
				<button
					class="flex-1 px-4 py-2 rounded-full bg-blue-500 text-white hover:bg-blue-600 transition text-sm font-medium"
					on:click={() => handleResetMessages(resetMessagesModalUser?.id)}
				>
					{$i18n.t('Reset')}
				</button>
			</div>
		</div>
	</div>
{/if}

{#if showResetExpiryModal}
	<div
		class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center"
		on:click={() => {
			showResetExpiryModal = false;
			resetMessagesModalUser = null;
			resetExpiryDate = '';
		}}
	>
		<div
			class="bg-white dark:bg-gray-850 rounded-2xl p-6 max-w-sm w-full mx-4 shadow-2xl"
			on:click|stopPropagation={() => {}}
		>
			<div class="text-center mb-4">
				<h3 class="text-lg font-semibold text-gray-900 dark:text-white">
					{$i18n.t('Reset Expiry')}
				</h3>
				<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
					{$i18n.t('Set new expiry date for {{email}}', { email: resetMessagesModalUser?.email })}
				</p>
			</div>
			<div class="mb-4">
				<label
					for="expiry-days"
					class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1"
				>
					{$i18n.t('Days from now')}
				</label>
				<input
					type="number"
					id="expiry-days"
					bind:value={resetExpiryDate}
					min="1"
					max="365"
					class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-transparent dark:bg-gray-800 text-sm"
				/>
			</div>
			<div class="flex gap-3">
				<button
					class="flex-1 px-4 py-2 rounded-full border border-gray-200 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition text-sm font-medium"
					on:click={() => {
						showResetExpiryModal = false;
						resetMessagesModalUser = null;
						resetExpiryDate = '';
					}}
				>
					{$i18n.t('Cancel')}
				</button>
				<button
					class="flex-1 px-4 py-2 rounded-full bg-yellow-500 text-white hover:bg-yellow-600 transition text-sm font-medium"
					on:click={handleResetExpiry}
				>
					{$i18n.t('Reset')}
				</button>
			</div>
		</div>
	</div>
{/if}
