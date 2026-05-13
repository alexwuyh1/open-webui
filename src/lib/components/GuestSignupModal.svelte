<script lang="ts">
	import { getContext } from 'svelte';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';
	import Modal from '$lib/components/common/Modal.svelte';
	import { guestSignUp } from '$lib/apis/auths';
	import { user as userStore } from '$lib/stores';
	import { getBackendConfig } from '$lib/apis';
	import { config as configStore } from '$lib/stores';

	export let show = false;

	const i18n = getContext('i18n');

	let email = '';
	let password = '';
	let confirmPassword = '';
	let submitting = false;
	let emailError = '';
	let passwordError = '';
	let confirmPasswordError = '';

	const validateEmail = (email: string) => {
		const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
		return re.test(email);
	};

	const validatePassword = (password: string) => {
		if (password.length < 8) {
			return $i18n.t('Password must be at least 8 characters');
		}
		return null;
	};

	const setSessionUser = async (sessionUser) => {
		if (sessionUser) {
			if (sessionUser.token) {
				localStorage.token = sessionUser.token;
			}
			await userStore.set(sessionUser);
			await configStore.set(await getBackendConfig());
			goto('/');
		}
	};

	const handleSubmit = async () => {
		emailError = '';
		passwordError = '';
		confirmPasswordError = '';

		if (!email.trim()) {
			emailError = $i18n.t('Email is required');
			return;
		}

		if (!validateEmail(email)) {
			emailError = $i18n.t('Please enter a valid email address');
			return;
		}

		if (password) {
			const pwdError = validatePassword(password);
			if (pwdError) {
				passwordError = pwdError;
				return;
			}

			if (password !== confirmPassword) {
				confirmPasswordError = $i18n.t('Passwords do not match');
				return;
			}
		}

		submitting = true;

		try {
			const sessionUser = await guestSignUp(email, password);
			if (sessionUser) {
				toast.success($i18n.t('Guest account created successfully!'));
				show = false;
				await setSessionUser(sessionUser);
			}
		} catch (error) {
			toast.error(error || $i18n.t('Failed to create guest account'));
		} finally {
			submitting = false;
		}
	};

	const resetForm = () => {
		email = '';
		password = '';
		confirmPassword = '';
		emailError = '';
		passwordError = '';
		confirmPasswordError = '';
	};

	$: if (!show) {
		resetForm();
	}
</script>

<Modal bind:show size="sm" containerClassName="flex items-center justify-center">
	<div class="flex flex-col items-center justify-center p-6 w-full">
		<div class="text-xl font-medium mb-2 text-center">
			{$i18n.t('Try as a Guest')}
		</div>
		<div class="text-sm text-gray-500 dark:text-gray-400 text-center mb-6">
			{$i18n.t(
				'Experience with 10 messages, valid for 7 days. Set a password to save your session.'
			)}
		</div>

		<form class="w-full flex flex-col gap-4" on:submit|preventDefault={handleSubmit}>
			<div>
				<label for="guest-email" class="text-sm font-medium text-left mb-1 block">
					{$i18n.t('Email')}
				</label>
				<input
					bind:value={email}
					type="email"
					id="guest-email"
					class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-transparent dark:bg-gray-800 text-sm outline-none placeholder:text-gray-400 dark:placeholder:text-gray-500"
					placeholder={$i18n.t('Enter your email')}
					disabled={submitting}
				/>
				{#if emailError}
					<div class="text-xs text-red-500 mt-1">{emailError}</div>
				{/if}
			</div>

			<div>
				<label for="guest-password" class="text-sm font-medium text-left mb-1 block">
					{$i18n.t('Password (optional)')}
				</label>
				<input
					bind:value={password}
					type="password"
					id="guest-password"
					class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-transparent dark:bg-gray-800 text-sm outline-none placeholder:text-gray-400 dark:placeholder:text-gray-500"
					placeholder={$i18n.t('Set a password to save your session')}
					disabled={submitting}
				/>
				{#if passwordError}
					<div class="text-xs text-red-500 mt-1">{passwordError}</div>
				{/if}
			</div>

			{#if password}
				<div>
					<label for="guest-confirm-password" class="text-sm font-medium text-left mb-1 block">
						{$i18n.t('Confirm Password')}
					</label>
					<input
						bind:value={confirmPassword}
						type="password"
						id="guest-confirm-password"
						class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-transparent dark:bg-gray-800 text-sm outline-none placeholder:text-gray-400 dark:placeholder:text-gray-500"
						placeholder={$i18n.t('Confirm your password')}
						disabled={submitting}
					/>
					{#if confirmPasswordError}
						<div class="text-xs text-red-500 mt-1">{confirmPasswordError}</div>
					{/if}
				</div>
			{/if}

			<div class="flex gap-3 mt-2">
				<button
					type="button"
					class="flex-1 px-4 py-2 rounded-full border border-gray-200 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition text-sm font-medium"
					on:click={() => {
						show = false;
					}}
					disabled={submitting}
				>
					{$i18n.t('Cancel')}
				</button>
				<button
					type="submit"
					class="flex-1 px-4 py-2 rounded-full bg-black dark:bg-white text-white dark:text-black hover:opacity-90 transition text-sm font-medium disabled:opacity-50"
					disabled={submitting}
				>
					{submitting ? $i18n.t('Creating...') : $i18n.t('Continue')}
				</button>
			</div>
		</form>
	</div>
</Modal>
