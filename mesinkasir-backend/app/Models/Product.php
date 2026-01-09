<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Product extends Model
{
    use HasFactory;

    protected $fillable = [
        'category_id',
        'name',
        'price',
        'qty',
        'active',
    ];

    protected $casts = [
        'category_id' => 'integer',
        'price' => 'integer',
        'qty' => 'integer',
        'active' => 'boolean',
    ];

    public function category(): BelongsTo
    {
        return $this->belongsTo(ProductCategory::class, 'category_id');
    }

    public function stocks()
    {
        return $this->belongsToMany(\App\Models\Stock::class, 'product_stock')
            ->withPivot(['id', 'qty', 'active'])
            ->withTimestamps();
    }
}
