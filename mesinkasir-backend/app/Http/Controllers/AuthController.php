<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;

use App\Models\User;

class AuthController extends Controller
{

    public function login(Request $request)
    {

        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
            'device_name' => ['required', 'string'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (!$user) {
            return response()->json(['message' => 'Email atau password salah'], 401);
        }

        if (isset($user->active) && !$user->active) {
            return response()->json(['message' => 'Akun nonaktif'], 403);
        }

        $valid = false;

        try {
            if ($user->role === 'kasir') {
                $valid = $user->pin_hash && Hash::check($validated['password'], $user->password);
            } else {
                $valid = $user->password && Hash::check($validated['password'], $user->password);
            }
        } catch (\Throwable $e) {
            $valid = false;
        }

        if (!$valid) {
            return response()->json(['message' => 'Email atau password salah'], 401);
        }

        $token = $user->createToken($validated['device_name'])->plainTextToken;

        return response()->json([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => $user,
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logout berhasil']);
    }
}
