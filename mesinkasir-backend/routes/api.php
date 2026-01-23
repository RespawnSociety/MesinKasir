<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\Kasir\KasirController;
use App\Http\Controllers\Pengaturantoko\PengaturantokoController;
use App\Http\Controllers\Product\ProductController;
use App\Http\Controllers\Product\StockController;
use App\Http\Controllers\Kasir\KasirTransaksiController;
use App\Http\Controllers\Transaksi\TransactionController;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', fn(\Illuminate\Http\Request $r) => $r->user());

    //API UNTUK KASIR
    Route::get('/kasirs', [KasirController::class, 'index']);
    Route::post('/kasirs', [KasirController::class, 'store']);
    Route::patch('/kasirs/{username}/active', [KasirController::class, 'setActive']);
    Route::patch('/kasirs/{username}/pin', [KasirController::class, 'resetPin']);
    Route::delete('/kasirs/{username}', [KasirController::class, 'destroy']);

    //API UNTUK PENGATURAN TOKO
    Route::get('/categories', [PengaturantokoController::class, 'categories']);
    Route::post('/categories', [PengaturantokoController::class, 'createCategory']);
    Route::patch('/categories/{category}/active', [PengaturantokoController::class, 'setCategoryActive']);
    Route::patch('/categories/{category}', [PengaturantokoController::class, 'updateCategory']);
    Route::delete('/categories/{category}', [PengaturantokoController::class, 'deleteCategory']);

    //UNTUK MENAMPILKAN STOCK DI PRODUCT
    Route::get('/products/stocks-master', [ProductController::class, 'stocksMaster']);

    //UNTUK PRODUCT
    Route::get('/products', [ProductController::class, 'index']);
    Route::get('/products/{product}', [ProductController::class, 'show']);
    Route::post('/products', [ProductController::class, 'store']);
    Route::patch('/products/{product}', [ProductController::class, 'update']);
    Route::delete('/products/{product}', [ProductController::class, 'destroy']);
    Route::get('/{product}/stocks', [ProductController::class, 'stocks']);
    Route::post('/{product}/stocks', [ProductController::class, 'attachStock']);
    Route::patch('/{product}/stocks/{stock}', [ProductController::class, 'updateStock']);
    Route::delete('/{product}/stocks/{stock}', [ProductController::class, 'detachStock']);

    //UNTUK STOCK
    Route::get('/stocks', [StockController::class, 'index']);
    Route::post('/stocks', [StockController::class, 'store']);
    Route::patch('/stocks/{stock}', [StockController::class, 'update']);
    Route::delete('/stocks/{stock}', [StockController::class, 'destroy']);

    //UNTUK PRODUCT STOCK
    Route::get('/products/{product}/stocks', [StockController::class, 'productStocks']);
    Route::post('/products/{product}/stocks', [StockController::class, 'attachToProduct']);
    Route::patch('/products/{product}/stocks/{stock}', [StockController::class, 'updateProductStock']);
    Route::delete('/products/{product}/stocks/{stock}', [StockController::class, 'detachFromProduct']);

    //UNTUK KASIR TRANSAKSI
    Route::prefix('kasir')->group(function () {
        Route::get('/categories', [KasirTransaksiController::class, 'categories']);
        Route::get('/products', [KasirTransaksiController::class, 'products']);
        Route::get('/products/count', [KasirTransaksiController::class, 'productsCount']);


        Route::get('/transactions', [TransactionController::class, 'index']);
        Route::get('/transactions/{id}', [TransactionController::class, 'show']);

        Route::get('/transactions/history', [TransactionController::class, 'history']);
        Route::get('/transactions/history/{id}', [TransactionController::class, 'historyShow']);

        Route::post('/transactions', [TransactionController::class, 'store']);
    });
});
